class_name HitStop
extends Node
## The only writer of Engine.time_scale (FX_MASTERPLAN.md §4.2):
##   time_scale = fast_forward × (slow_scale while a hitstop runs, else 1) × cutscene_factor
## TurnDirector sets fast_forward (hold Space on the rival turn); FxDirector asks for hitstops.
## Hitstops are timed in real milliseconds, so they last the same however slow the game runs.

## Game speed during a hitstop. Not 0: tweens and timers creep on instead of stalling.
@export_range(0.0, 0.5, 0.01) var slow_scale := 0.03

var fast_forward := 1.0:
	set(v):
		fast_forward = v
		_apply()
## Set by a cutscene to freeze the world while its close-up plays on real time.
var cutscene_factor := 1.0:
	set(v):
		cutscene_factor = v
		_apply()
var _until_ms := 0


## Freeze for `seconds` of real time. Overlapping requests do not stack: the later end wins.
func request(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_until_ms = maxi(_until_ms, Time.get_ticks_msec() + int(seconds * 1000.0))
	_apply()


func active() -> bool:
	return Time.get_ticks_msec() < _until_ms


func clear() -> void:
	_until_ms = 0
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _apply() -> void:
	Engine.time_scale = fast_forward * (slow_scale if active() else 1.0) * cutscene_factor
