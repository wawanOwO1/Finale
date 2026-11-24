extends SceneTree
## FX frame-time check in a real window (FX_MASTERPLAN.md §7.1, §10): starts a duel, then fires every
## cue, the Signature cutscene and the finish once each, and records every frame's time. A shader or
## overlay that compiles on first use shows up as a spike: the test fails when the worst frame is
## far above the median (ratio, so it works on a fast GPU and on a slow software renderer alike).
## Run (needs a window, not --headless):
##   godot --path godot --resolution 1600x900 --script res://tests/fx_drive.gd

## Worst frame may be at most this many times the median frame.
const MAX_SPIKE := 4.0

var failures := 0
var _frames: PackedFloat32Array = []
var _last := 0
var _recording := false


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.dev_deck = true
	var keeper: AlmanacKeeper = main.get_node("AlmanacKeeper")
	keeper.save_path = OS.get_user_data_dir().path_join("almanac_fx_drive.save")
	root.add_child(main)
	await _wait(0.6)
	main.ui.get_node("%StartButton").pressed.emit()
	while main.ui.vs_intro().visible or main.ui._announcer.visible or main.duel == null:
		await _wait(0.1)
	await _wait(1.5)
	var fx: FxDirector = main.fx
	var ui: DuelUI = main.ui
	var d: Duel = main.duel
	fx.auto_quality = false
	process_frame.connect(_tick)
	# Baseline: idle frames.
	_recording = true
	await _wait(1.0)
	var idle := _median()
	print("idle median %.1f ms (%d frames)" % [idle, _frames.size()])
	# Every cue once, first time each.
	var at: Vector2 = ui.serve_rect("player").get_center()
	for cue in [fx.place, fx.serve, fx.serve_big, fx.serve_burnt, fx.big_hit, fx.signature]:
		fx.play(cue, at, Color.WHITE, "enemy")
		await _wait(0.6)
		fx.hit_stop.clear()
	# The Signature cutscene (long) and the finish, through the real signals.
	d.signature_served.emit("player", "Omelette")
	await _wait(2.8)
	d._lose_confidence("enemy", 999, "pressure")
	d.changed.emit()
	await _wait(2.5)
	_recording = false
	var med := _median()
	var worst := 0.0
	for f in _frames:
		worst = maxf(worst, f)
	print("frames %d  median %.1f ms  worst %.1f ms  (x%.1f)" % [_frames.size(), med, worst, worst / med])
	_check("no first-use spike: worst %.1f ms <= %.1f x median %.1f ms" % [worst, MAX_SPIKE, med], worst <= med * MAX_SPIKE)
	_check("FX cost little: median with FX %.1f ms vs idle %.1f ms" % [med, idle], med <= idle * 1.5 + 2.0)
	print("FX DRIVE: %s" % ("all checks passed" if failures == 0 else "%d failed" % failures))
	quit(1 if failures else 0)


func _tick() -> void:
	var now := Time.get_ticks_usec()
	if _recording and _last > 0:
		_frames.append((now - _last) / 1000.0)
	_last = now


func _median() -> float:
	var a := _frames.duplicate()
	a.sort()
	return a[a.size() / 2] if a.size() > 0 else 0.0


## Real-time wait (cutscenes slow the game clock on purpose).
func _wait(t: float) -> void:
	await create_timer(t, true, false, true).timeout


func _check(what: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("PASS  " if ok else "FAIL  ") + what)
