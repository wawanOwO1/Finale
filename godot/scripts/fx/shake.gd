class_name Shake
extends Node
## Trauma screen shake (FX_MASTERPLAN.md §4.3). Moves the stage camera through h_offset /
## v_offset (its transform stays put, so _fit_camera and screen_pos keep working) and the HUD
## CanvasLayer's offset, snapped to the 3 px art grid so the pixel HUD stays crisp.
## Runs on real time, so it keeps shaking through a hitstop.

## Trauma lost per second.
@export_range(0.1, 5.0, 0.1) var decay := 1.6
## Camera offset at trauma 1, in world units.
@export_range(0.0, 2.0, 0.05) var max_camera := 0.45
## HUD offset at trauma 1, in design pixels (1920x1080).
@export_range(0.0, 60.0, 1.0) var max_hud := 18.0
## Noise speed: higher = more jittery.
@export_range(1.0, 60.0, 1.0) var frequency := 22.0
## HUD offsets are rounded to this grid (1 art pixel = 3 screen px, ART_DIRECTION §2.1).
@export var hud_grid := 3.0
## Settings menu: 0 = no shake.
@export_range(0.0, 2.0, 0.05) var strength := 1.0

## Punch zoom (FOV) spring-back time, real seconds.
@export_range(0.05, 1.0, 0.01) var punch_time := 0.28

var camera: Camera3D
var hud: CanvasLayer
var trauma := 0.0
var _noise := FastNoiseLite.new()
var _last_ms := 0
var _punch := 0.0
var _punch_at := -100000
var _base_fov := 0.0


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_last_ms = Time.get_ticks_msec()


## Raise trauma to at least `amount` (no stacking past the strongest hit).
func add(amount: float) -> void:
	trauma = clampf(maxf(trauma, amount), 0.0, 1.0)


## Narrow the stage camera's FOV by `amount` (0.03 = 3%) and spring back. Strongest wins.
func punch(amount: float) -> void:
	if amount <= 0.0 or camera == null:
		return
	if amount >= punch_value():
		if punch_value() == 0.0:
			_base_fov = camera.fov
		_punch = amount
		_punch_at = Time.get_ticks_msec()


func punch_value() -> float:
	var t := (Time.get_ticks_msec() - _punch_at) / 1000.0
	if t < 0.0 or t >= punch_time:
		return 0.0
	# Snap in at once, ease back out.
	var k := 1.0 - t / punch_time
	return _punch * k * k


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if camera and _base_fov > 0.0:
		var z := punch_value()
		camera.fov = _base_fov * (1.0 - z)
		if z == 0.0:
			_base_fov = 0.0
	var dt := (now - _last_ms) / 1000.0
	_last_ms = now
	trauma = maxf(0.0, trauma - decay * dt)
	var k := trauma * trauma * strength
	var t := now / 1000.0 * frequency
	var nx := _noise.get_noise_2d(t, 0.0)
	var ny := _noise.get_noise_2d(0.0, t + 100.0)
	if camera:
		camera.h_offset = nx * max_camera * k
		camera.v_offset = ny * max_camera * k
	if hud:
		var o := Vector2(nx, ny) * max_hud * k
		hud.offset = (o / hud_grid).round() * hud_grid if hud_grid > 0.0 else o


func offset() -> Vector2:
	return hud.offset if hud else Vector2.ZERO
