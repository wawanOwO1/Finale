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
@export_group("Cuisine (GDD §4.11)")
## Flat Pressure added when your dish is the rival's weakness (after every multiplier).
@export_range(0, 30) var weakness_bonus := Duel.WEAKNESS_BONUS
## Flat Pressure taken off when your dish is their Specialty or your known Reputation.
@export_range(0, 30) var specialty_penalty := Duel.SPECIALTY_PENALTY
## Hype gained on a weakness hit.
@export_range(0, 50) var weakness_hype := Duel.WEAKNESS_HYPE
## Heat the rival loses on its next turn after a weakness hit (Stumped).
@export_range(0, 3) var stumped_heat := Duel.STUMPED_HEAT
## Serves of one cuisine before it becomes your run Reputation.
@export_range(1, 20) var reputation_threshold := RunState.REPUTATION_THRESHOLD
@export_group("")
## Run (RunState): after a win the next duel starts with the Confidence you have left.
## Off = every duel starts at full Confidence (handy for replaying one matchup).
@export var carry_confidence := true
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
## Apis's Signature Dish cutscene (FX_MASTERPLAN.md §6.2); beats in its AnimationPlayer.
@onready var signature_cutscene: SignatureCutscene = $SignatureCutscene
## End-of-duel cutscene (§6.3) before FINISHED / YOU WINS!; beats in its AnimationPlayer.
@onready var finish_cutscene: FinishCutscene = $FinishCutscene

var duel: Duel
## Deck, Confidence, Tips, books and Tools carried from duel to duel.
var run: RunState
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
	signature_cutscene.setup(stage, ui, fx)
	fx.cutscene = signature_cutscene
	finish_cutscene.setup(stage, ui, fx)
	fx.finish = finish_cutscene
	ui.fx = fx
	ui.fx_debug().fx = fx
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


## A new run: the Inspector's deck / books / Confidence until the Course Path picks them.
func _new_run() -> void:
	run = RunState.start(player_confidence, "dev" if dev_deck else RunState.START_DECK,
			GameDB.ALL_BOOKS if dev_deck else RunState.START_BOOKS)
	run.reputation_threshold = reputation_threshold


func _start_duel() -> void:
	# The run carries between duels: a win keeps the Confidence you have left, a loss starts over.
	# Restarting a duel in progress replays it from the run as it was.
	if run == null or (duel and duel.phase == "lost"):
		_new_run()
	elif duel and duel.phase == "won":
		round_number += 1
		run.finish_duel(duel)
		if not carry_confidence:
			run.confidence = run.max_confidence
	var recipes := run.recipes()
	almanac_keeper.prepare(run.deck, recipes)
	stage.set_plate([])
	stage.crowd_still = false
	Audio.play_music("deck")
	await ui.show_cookbook(recipes)
	ui.round_number = round_number
	duel = run.new_duel(GameDB.enemy(enemy_id), {hype = start_hype, player_flow = player_flow,
			weakness_bonus = weakness_bonus, specialty_penalty = specialty_penalty,
			weakness_hype = weakness_hype, stumped_heat = stumped_heat})
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
	stage.cut_pixel_post.visible = on
	ui.set_pixel_on(on)
