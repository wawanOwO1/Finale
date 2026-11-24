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

var camera: Camera3D
var hud: CanvasLayer
var trauma := 0.0
var _noise := FastNoiseLite.new()
var _last_ms := 0


func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 1.0
	_last_ms = Time.get_ticks_msec()


## Raise trauma to at least `amount` (no stacking past the strongest hit).
func add(amount: float) -> void:
	trauma = clampf(maxf(trauma, amount), 0.0, 1.0)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
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
