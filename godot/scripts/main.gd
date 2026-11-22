extends Node
## Graybox entry point: one duel. Pick the setup in the Inspector (select Main) instead of
## the old URL params (?enemy=rosa, ?deck=dev, ?hype=100).

@export_enum("tony", "rosa") var enemy_id := "tony"
## Starter deck + status cards and all four Recipe Books.
@export var dev_deck := false
## 100 = Signature Dish in hand from turn 1.
@export_range(0, 100) var start_hype := 0
## Vertical resolution of the 3D view when the pixel filter is on.
@export var pixel_height := 360

@onready var view: SubViewportContainer = $StageView
@onready var stage: Stage = $StageView/StageViewport/Stage
@onready var ui: DuelUI = $DuelUI
## Turn pacing (GRAND_DESIGN §1); timings are in its Inspector.
@onready var director: TurnDirector = $TurnDirector

var duel: Duel
var pixelated := false
## Duel number shown by the announcer ("ROUND 2"). Goes up after a win.
var round_number := 1


func _ready() -> void:
	ui.restart_requested.connect(_start_duel)
	ui.pixel_toggled.connect(_toggle_pixel)
	director.ui = ui
	ui.director = director
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
	}


func _start_duel() -> void:
	var books: PackedStringArray = GameDB.ALL_BOOKS if dev_deck else PackedStringArray(["basics"])
	var recipes := GameDB.book_recipes(books)
	stage.set_plate([])
	Audio.play_music("deck")
	await ui.show_cookbook(recipes)
	if duel and duel.phase == "won":
		round_number += 1
	ui.round_number = round_number
	duel = Duel.new(GameDB.deck("dev" if dev_deck else "starter"), GameDB.enemy(enemy_id), recipes,
			{hype = start_hype})
	# Visuals listen to the duel's signals; the duel never knows about them (GDD §9).
	duel.changed.connect(_sync_plate)
	duel.confidence_lost.connect(func(target: String, _amount: int, _source: String) -> void:
		stage.hit("rival" if target == "enemy" else "player"))
	ui.bind(duel)
	Audio.bind(duel)
	_sync_plate()


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


## Pixel filter: render the 3D view at ~360p and upscale it with nearest filtering.
func _toggle_pixel() -> void:
	pixelated = not pixelated
	view.stretch_shrink = maxi(1, roundi(view.size.y / pixel_height)) if pixelated else 1
	ui.set_pixel_on(pixelated)
