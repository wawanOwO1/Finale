class_name FxDirector
extends Node
## Screen feel for duel moments (FX_MASTERPLAN.md §3–4). Listens to Duel signals, like Audio and
## DuelUI: the duel never knows it exists. Each moment is an FxCue (.tres in data/fx/) set in this
## node's Inspector; HitStop and Shake are child nodes with their own settings.
##
## Wired in main.gd: fx.setup(stage, ui), then fx.bind(duel) for each new duel.

@export_group("Cues")
## An ingredient lands on a station (T0: crumbs in the ingredient's color).
@export var place: FxCue
## Any recipe or Improvised Serve that lands.
@export var serve: FxCue
## Perfect Order, or a Serve taking at least big_pressure.
@export var serve_big: FxCue
## A Burnt (halved) Serve.
@export var serve_burnt: FxCue
## Losing at least big_hit_ratio of max Confidence in one go (either side).
@export var big_hit: FxCue
@export var signature: FxCue
@export var win: FxCue
@export var lose: FxCue
@export_group("Thresholds")
## Pressure that turns a Serve into serve_big.
@export var big_pressure := 15
@export_range(0.05, 1.0, 0.05) var big_hit_ratio := 0.25
@export_group("Accessibility")
## Settings menu: flashes at reduce_flash_scale of their alpha.
@export var reduce_flashing := false
@export_range(0.0, 1.0, 0.05) var reduce_flash_scale := 0.4
@export_group("Crack")
## Seconds a Confidence-bar crack takes to fade.
@export_range(0.1, 3.0, 0.05) var crack_time := 0.9

@onready var hit_stop: HitStop = $HitStop
@onready var shake: Shake = $Shake

var duel: Duel
var stage: Stage
var ui: DuelUI
var hud: FxHud
## The FxScreen overlay (ColorRect with fx_screen.gdshader) from duel_ui.tscn.
var screen: CanvasItem
var _mat: ShaderMaterial
## Real-time envelopes, in milliseconds since start.
var _flash_peak := 0.0
var _flash_color := Color.WHITE
var _flash_at := -100000
var _flash_len := 150
var _desat_peak := 0.0
var _desat_at := -100000
var _desat_hold := 0
var _desat_fade := 400
## Prewarm frames left (§7.1): the overlay draws invisibly so WebGL compiles it before the first hit.
var _warm := 0
## Last cue played (tests).
var last_cue: FxCue


var _crack_tw := {}


func setup(stage_: Stage, ui_: DuelUI) -> void:
	stage = stage_
	ui = ui_
	hud = ui.fx_hud()
	shake.camera = stage.camera
	shake.hud = ui
	screen = ui.fx_screen()
	_mat = screen.material as ShaderMaterial
	prewarm()


func bind(d: Duel) -> void:
	duel = d
	hit_stop.clear()
	shake.trauma = 0.0
	_flash_peak = 0.0
	_desat_peak = 0.0
	d.card_played.connect(_on_card_played)
	d.dish_revealed.connect(_on_dish_revealed)
	d.dish_served.connect(_on_dish_served)
	d.confidence_lost.connect(_on_confidence_lost)
	d.signature_served.connect(func(side: String, _dish: String) -> void:
		play(signature, _serve_point(side)))
	d.duel_ended.connect(func(winner: String) -> void:
		var loser := "enemy" if winner == "player" else "player"
		play(win if winner == "player" else lose, _hit_point(loser), Color.WHITE, loser))


## Fire a cue. Values merge with what is already running (strongest wins), so a Serve that fires
## three signals in one frame still feels like one hit.
##   at: HUD position for its particles and word (Vector2.INF = screen-wide parts only).
##   tint: particle color (crumbs take the ingredient's tag color).
##   target: side whose Confidence bar cracks ("player" | "enemy"), if the cue cracks.
func play(cue: FxCue, at := Vector2.INF, tint := Color.WHITE, target := "") -> void:
	if cue == null:
		return
	last_cue = cue
	hit_stop.request(cue.hitstop)
	shake.add(cue.trauma)
	shake.punch(cue.zoom_punch)
	if stage:
		stage.cheer(cue.crowd)
	if hud and at != Vector2.INF:
		hud.burst(cue.burst, at, tint)
		hud.burst(cue.burst_2, at, Color.WHITE)
		hud.word(cue.word, at - Vector2(0, Pal.em(3.0)), cue.word_color, maxi(1, cue.tier))
	if cue.crack and ui and target != "":
		_crack(ui.hp_bar(target))
	var now := Time.get_ticks_msec()
	var peak := cue.flash * (reduce_flash_scale if reduce_flashing else 1.0)
	if peak > 0.0 and peak >= _flash_value(now):
		_flash_peak = peak
		_flash_color = cue.flash_color
		_flash_at = now
		_flash_len = int(cue.flash_time * 1000.0)
	if cue.desat > 0.0 and cue.desat >= _desat_value(now):
		_desat_peak = cue.desat
		_desat_at = now
		_desat_hold = int(cue.desat_hold * 1000.0)
		_desat_fade = int(cue.desat_fade * 1000.0)
	_update_screen()


## Draw the overlay for a couple of frames with tiny values (below 1/255, invisible), so the
## shader and its screen copy are compiled now and not on the first Serve.
func prewarm() -> void:
	_warm = 2
	_update_screen()
	if hud:
		hud.prewarm()


func _crack(bar: HpBar) -> void:
	bar.crack_seed = randi()
	bar.crack = 1.0
	var old: Tween = _crack_tw.get(bar)
	if old and old.is_valid():
		old.kill()
	var tw := create_tween()
	tw.tween_interval(crack_time * 0.4)
	tw.tween_property(bar, "crack", 0.0, crack_time * 0.6)
	_crack_tw[bar] = tw


func _serve_point(side: String) -> Vector2:
	return ui.serve_rect(side).get_center() if ui else Vector2.INF


func _hit_point(target: String) -> Vector2:
	return ui.hit_point(target) if ui else Vector2.INF


func flash_value() -> float:
	return _flash_value(Time.get_ticks_msec())


func desat_value() -> float:
	return _desat_value(Time.get_ticks_msec())


func _process(_delta: float) -> void:
	if _warm > 0:
		_warm -= 1
	_update_screen()


func _update_screen() -> void:
	if screen == null:
		return
	var now := Time.get_ticks_msec()
	var f := _flash_value(now)
	var d := _desat_value(now)
	var on := f > 0.0 or d > 0.0 or _warm > 0
	screen.visible = on
	if on and _mat:
		_mat.set_shader_parameter("flash", maxf(f, 0.001 if _warm > 0 else 0.0))
		_mat.set_shader_parameter("flash_color", _flash_color)
		_mat.set_shader_parameter("desat", maxf(d, 0.001 if _warm > 0 else 0.0))


func _flash_value(now: int) -> float:
	var t := now - _flash_at
	if t < 0 or t >= _flash_len:
		return 0.0
	return _flash_peak * (1.0 - float(t) / _flash_len)


func _desat_value(now: int) -> float:
	var t := now - _desat_at
	if t < 0 or t >= _desat_hold + _desat_fade:
		return 0.0
	if t < _desat_hold:
		return _desat_peak
	return _desat_peak * (1.0 - float(t - _desat_hold) / _desat_fade)


func _on_card_played(side: String, card: CardInstance) -> void:
	if ui and card.def.is_ingredient():
		play(place, ui.card_point(side, card), Pal.tag_color(card.def.first_tag()).lightened(0.25))


func _on_dish_revealed(side: String, _recipe: RecipeDef, perfect: bool, sig: bool, burnt: bool) -> void:
	if sig:
		return  # signature_served already played its cue
	if burnt:
		play(serve_burnt, _serve_point(side))
	elif perfect:
		play(serve_big, _serve_point(side))


func _on_dish_served(side: String, _recipe: RecipeDef, pressure: int, _quality: int, _count: int) -> void:
	if pressure >= big_pressure:
		play(serve_big, _serve_point(side))
	elif pressure > 0:
		play(serve, _serve_point(side))


func _on_confidence_lost(target: String, amount: int, source: String) -> void:
	if source != "pressure" or duel == null:
		return
	var f := duel.fighter(target)
	if amount >= f.max_confidence * big_hit_ratio:
		# Shards and "CRACK!" on the bar that cracks; the slammed number stays over the chef.
		play(big_hit, ui.hp_bar(target).get_global_rect().get_center() + Vector2(0, Pal.em(3.0)), Color.WHITE, target)
