extends Node
## Graybox entry point: one duel. Pick the setup in the Inspector (select Main) instead of
## the old URL params (?enemy=rosa, ?deck=dev, ?hype=100).

@export_enum("tony", "rosa") var enemy_id := "tony"
## Starter deck + status cards and all four Recipe Books.
@export var dev_deck := false
## 100 = Signature Dish in hand from turn 1.
@export_range(0, 100) var start_hype := 0
@export_group("Balance (GRAND_DESIGN §8 G, check with tests/balance.gd)")
## Apis's Confidence at the start of a duel.
@export_range(10, 300) var player_confidence := Duel.PLAYER_CONFIDENCE
## Chef's Flow: Perfect Serves needed for each modifier; the last value repeats.
@export var player_flow: PackedInt32Array = Duel.PLAYER_FLOW
@export_group("")
## Vertical resolution of the 3D view when the pixel filter is on.
@export var pixel_height := 270
## Start with the pixel filter on (P / the HUD button toggles it). Only the 3D view; the HUD stays sharp.
@export var pixel_on_start := true

@onready var view: SubViewportContainer = $StageView
@onready var stage: Stage = $StageView/StageViewport/Stage
@onready var ui: DuelUI = $DuelUI
## Turn pacing (GRAND_DESIGN §1); timings are in its Inspector.
@onready var director: TurnDirector = $TurnDirector
## Discovery + save (GRAND_DESIGN §6); the window is the Almanac node in duel_ui.tscn.
@onready var almanac_keeper: AlmanacKeeper = $AlmanacKeeper
## Hitstop, shake, flash (FX_MASTERPLAN.md); cues are in its Inspector.
@onready var fx: FxDirector = $FxDirector

var duel: Duel
var pixelated := false
## Duel number shown by the announcer ("ROUND 2"). Goes up after a win.
var round_number := 1


func _ready() -> void:
	ui.restart_requested.connect(_start_duel)
	ui.pixel_toggled.connect(func() -> void: _set_pixel(not pixelated))
	view.resized.connect(func() -> void: _set_pixel(pixelated))
	_set_pixel(pixel_on_start)
	director.ui = ui
	director.hit_stop = fx.hit_stop
	fx.setup(stage, ui)
	ui.director = director
	ui.almanac_keeper = almanac_keeper
	director.rival_acted.connect(func(_a: Dictionary) -> void: stage.act("rival"))
	_start_duel()


## F11 = real fullscreen. Do not drag the window bigger than the screen instead: Windows then
## moves it, and the mouse no longer lines up with what is drawn.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F11:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


func _process(_delta: float) -> void:
	# HUD blocks that follow the 3D stage (rival HUD, Prep Board, floating numbers).
	ui.anchors = {
		rival = _screen(stage.rival_intent_anchor),
		player = _screen(stage.player_anchor),
		board = _screen(stage.board_anchor),
		rival_stations = _screen(stage.rival_stations_anchor),
	}


func _start_duel() -> void:
	var books: PackedStringArray = GameDB.ALL_BOOKS if dev_deck else PackedStringArray(["basics"])
	var recipes := GameDB.book_recipes(books)
	var deck := GameDB.deck("dev" if dev_deck else "starter")
	almanac_keeper.prepare(deck, recipes)
	stage.set_plate([])
	Audio.play_music("deck")
	await ui.show_cookbook(recipes)
	if duel and duel.phase == "won":
		round_number += 1
	ui.round_number = round_number
	duel = Duel.new(deck, GameDB.enemy(enemy_id), recipes,
			{hype = start_hype, max_confidence = player_confidence, player_flow = player_flow})
	# Visuals listen to the duel's signals; the duel never knows about them (GDD §9).
	duel.changed.connect(_sync_plate)
	duel.confidence_lost.connect(func(target: String, _amount: int, _source: String) -> void:
		stage.hit("rival" if target == "enemy" else "player"))
	_bind_chefs()
	almanac_keeper.watch(duel)
	ui.bind(duel)
	Audio.bind(duel)
	fx.bind(duel)
	_sync_plate()


## Chef clips (ANIMATION_DESIGN.md): card placed → chop, dish served → busy,
## duel over → victory / lose (held until the next duel).
func _bind_chefs() -> void:
	stage.rival.character = enemy_id
	stage.player.reset()
	stage.rival.reset()
	duel.card_played.connect(func(side: String, _card: CardInstance) -> void:
		stage.chef(side).perform("chop"))
	duel.dish_served.connect(func(side: String, _r: RecipeDef, _p: int, _q: int, _n: int) -> void:
		stage.chef(side).perform("busy"))
	duel.duel_ended.connect(func(winner: String) -> void:
		stage.chef(winner).finish("victory")
		stage.chef("enemy" if winner == "player" else "player").finish("lose"))


func _sync_plate() -> void:
	var tags: Array = []
	# 3D plate shows the fullest station (the one closest to a dish).
	var biggest: Array[CardInstance] = []
	for s: Array[CardInstance] in duel.stations:
		if s.size() > biggest.size():
			biggest = s
	for c in biggest:
		tags.append(c.def.first_tag())
	stage.set_plate(tags)


## 3D anchor → HUD (canvas) coordinates, through the SubViewport's shrink factor.
func _screen(anchor: Node3D) -> Vector2:
	return view.position + stage.screen_pos(anchor) * view.stretch_shrink


## Pixel filter: render the 3D view at ~360p, upscale it with nearest filtering, and run the
## post-process quad (outlines + posterized palette). MSAA off, or edges get smoothed back.
func _set_pixel(on: bool) -> void:
	pixelated = on
	view.stretch_shrink = maxi(1, roundi(view.size.y / pixel_height)) if on else 1
	var vp: SubViewport = view.get_node("StageViewport")
	vp.msaa_3d = Viewport.MSAA_DISABLED if on else Viewport.MSAA_2X
	stage.pixel_post.visible = on
	ui.set_pixel_on(on)
