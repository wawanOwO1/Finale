class_name FxDirector
extends Node
## Screen feel for duel moments (FX_MASTERPLAN.md §3–4). Listens to Duel signals, like Audio and
## DuelUI: the duel never knows it exists. Each moment is an FxCue (.tres in data/fx/) set in this
## node's Inspector; HitStop and Shake are child nodes with their own settings.
##
## Wired in main.gd: fx.setup(stage.camera, ui), then fx.bind(duel) for each new duel.

@export_group("Cues")
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

@onready var hit_stop: HitStop = $HitStop
@onready var shake: Shake = $Shake

var duel: Duel
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


func setup(camera: Camera3D, ui: DuelUI) -> void:
	shake.camera = camera
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
	d.dish_revealed.connect(_on_dish_revealed)
	d.dish_served.connect(_on_dish_served)
	d.confidence_lost.connect(_on_confidence_lost)
	d.signature_served.connect(func(_side: String, _dish: String) -> void: play(signature))
	d.duel_ended.connect(func(winner: String) -> void: play(win if winner == "player" else lose))


## Fire a cue. Values merge with what is already running (strongest wins), so a Serve that fires
## three signals in one frame still feels like one hit.
func play(cue: FxCue) -> void:
	if cue == null:
		return
	last_cue = cue
	hit_stop.request(cue.hitstop)
	shake.add(cue.trauma)
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


func _on_dish_revealed(_side: String, _recipe: RecipeDef, perfect: bool, sig: bool, burnt: bool) -> void:
	if sig:
		return  # signature_served already played its cue
	if burnt:
		play(serve_burnt)
	elif perfect:
		play(serve_big)


func _on_dish_served(_side: String, _recipe: RecipeDef, pressure: int, _quality: int, _count: int) -> void:
	if pressure >= big_pressure:
		play(serve_big)
	elif pressure > 0:
		play(serve)


func _on_confidence_lost(target: String, amount: int, source: String) -> void:
	if source != "pressure" or duel == null:
		return
	var f := duel.fighter(target)
	if amount >= f.max_confidence * big_hit_ratio:
		play(big_hit)
