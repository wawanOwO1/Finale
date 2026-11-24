class_name FxCutscene
extends Node
## Shared machinery for in-engine cutscenes (FX_MASTERPLAN.md §6): SignatureCutscene, FinishCutscene.
##
## The beats are method keys in the AnimationPlayer child: move them in the animation editor to
## retime a scene. The player runs in manual mode, advanced on real time, so a scene keeps going
## while it slows or freezes the world (HitStop.cutscene_factor). Click, Space, Enter or Esc skips to
## `skip_beat` (then to the end). Beats only touch visuals: skipping or aborting never breaks a duel.
##
## Several cutscenes can overlap (a Signature that ends the duel runs into the finish): the letterbox
## and the HUD only come back when the last one closes.

signal finished

## Turn the cutscene off (callers then fall back to the plain effects).
@export var enabled := true
## Beat that a skip jumps to ("" = straight to the end).
@export var skip_beat := ""
@export_group("Letterbox & HUD")
## Height of each black bar, design px (1080 high).
@export var letterbox_px := 120.0
## Fade of the HUD, real seconds.
@export_range(0.0, 1.0, 0.01) var hud_fade := 0.15
@export_range(0.05, 1.0, 0.01) var letterbox_time := 0.22

## Cutscenes playing right now (letterbox / HUD are shared).
static var _active: Array = []

@onready var anim: AnimationPlayer = $AnimationPlayer

var stage: Stage
var ui: DuelUI
var fx: FxDirector
var playing := false
## Running animation ("long", "short", "win", …).
var version := ""
var _last_ms := 0
var _skipped := false
var _tweens: Array[Tween] = []
## Camera move on real time: from → to over _cam_len seconds (ease out).
var _cam_t := -1.0
var _cam_len := 1.0
var _cam_from: Transform3D
var _cam_to: Transform3D
var _fov_from := 30.0
var _fov_to := 30.0


func setup(stage_: Stage, ui_: DuelUI, fx_: FxDirector) -> void:
	stage = stage_
	ui = ui_
	fx = fx_
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Beats run inside advance(), not deferred to the end of the frame.
	anim.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	set_process(false)


## Start animation `name` from the top.
func start(name: String) -> void:
	if playing:
		abort()
	version = name
	playing = true
	_skipped = false
	if not _active.has(self):
		_active.append(self)
	_last_ms = Time.get_ticks_msec()
	set_process(true)
	anim.play(name)
	# Fire the opening key now, in the same frame as the hit: the first advance after play() only
	# sets the player up, the second one crosses the key at 0.
	anim.advance(0.0)
	anim.advance(0.001)


## Jump to skip_beat (input). Past it, or without one, finish at once.
func skip() -> void:
	if not playing:
		return
	var t := beat_time(skip_beat) if skip_beat != "" else -1.0
	if not _skipped and t >= 0.0 and anim.current_animation_position < t:
		_skipped = true
		anim.seek(t + 0.001, true)
		call(skip_beat)
	else:
		close()


## Stop now and put everything back (new duel). Subclasses restore their own state in _on_abort().
func abort() -> void:
	if not playing:
		return
	_on_abort()
	close()
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	if _active.is_empty():
		reset_shared(ui)


## Time of a beat in the running animation, -1 if missing.
func beat_time(method: String) -> float:
	var a := anim.get_animation(version) if anim.has_animation(version) else null
	if a == null:
		return -1.0
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_METHOD:
			continue
		for k in a.track_get_key_count(t):
			if a.method_track_get_name(t, k) == method:
				return a.track_get_key_time(t, k)
	return -1.0


## End of the scene (also keyed as the last beat). Letterbox / HUD come back if no other scene runs.
func close() -> void:
	if not playing:
		return
	playing = false
	set_process(false)
	anim.stop()
	_cam_t = -1.0
	_on_close()
	_active.erase(self)
	if _active.is_empty():
		if stage:
			stage.camera.make_current()
		_letterbox(false)
		_fade_hud(1.0)
		fx.hit_stop.cutscene_factor = 1.0
		if ui.duel and not ui.duel.over():
			ui.set_busy(false)
	finished.emit()


## Letterbox, HUD and camera back to normal at once (new duel, tests).
static func reset_shared(ui_: DuelUI) -> void:
	_active.clear()
	if ui_ == null:
		return
	ui_.hud_root().modulate.a = 1.0
	var box := ui_.letterbox()
	box.hide()
	(box.get_node("LetterTop") as Control).offset_bottom = 0.0
	(box.get_node("LetterBottom") as Control).offset_top = 0.0


func _process(_delta: float) -> void:
	if not playing:
		return
	var now := Time.get_ticks_msec()
	var dt := (now - _last_ms) / 1000.0
	_last_ms = now
	anim.advance(dt)
	if _cam_t >= 0.0 and stage:
		_cam_t += dt
		var k := clampf(_cam_t / _cam_len, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		stage.cut_camera.global_transform = _cam_from.interpolate_with(_cam_to, k)
		stage.cut_camera.fov = lerpf(_fov_from, _fov_to, k)
	if playing and not anim.is_playing():
		close()


func _input(event: InputEvent) -> void:
	if not playing:
		return
	var skip_it := false
	if event is InputEventMouseButton and event.pressed:
		skip_it = true
	elif event is InputEventKey and event.pressed and not event.echo:
		skip_it = event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER]
	if skip_it:
		get_viewport().set_input_as_handled()
		skip()


# ---------------------------------------------------------------- for subclasses

## Subclass hook: undo anything only this scene changed (abort).
func _on_abort() -> void:
	pass


## Subclass hook: called once when the scene ends (any way).
func _on_close() -> void:
	pass


## Put CutCamera on `from` and move it to `to` over `seconds` (real time), and make it current.
func _move_camera(from: Transform3D, to: Transform3D, seconds: float, fov_from: float, fov_to: float) -> void:
	_cam_from = from
	_cam_to = to
	_cam_len = maxf(0.1, seconds)
	_cam_t = 0.0
	_fov_from = fov_from
	_fov_to = fov_to
	stage.cut_camera.global_transform = from
	stage.cut_camera.fov = fov_from
	stage.cut_camera.make_current()


## Global transform of a Marker3D under the stage, or the duel camera's if missing.
func _marker(path: NodePath) -> Transform3D:
	var m := stage.get_node_or_null(path) as Node3D
	return m.global_transform if m else stage.camera.global_transform


func _letterbox(on: bool) -> void:
	var box := ui.letterbox()
	var top: Control = box.get_node("LetterTop")
	var bottom: Control = box.get_node("LetterBottom")
	box.show()
	var tw := _tween()
	tw.tween_property(top, "offset_bottom", letterbox_px if on else 0.0, letterbox_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bottom, "offset_top", -letterbox_px if on else 0.0, letterbox_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not on:
		tw.tween_callback(func() -> void: if _active.is_empty(): box.hide())


func _fade_hud(alpha: float, time := -1.0) -> void:
	var tw := _tween()
	tw.tween_property(ui.hud_root(), "modulate:a", alpha, hud_fade if time < 0.0 else time)


## Real-time tweens (they run while the world is frozen).
func _tween() -> Tween:
	var tw := create_tween().set_ignore_time_scale(true)
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid())
	_tweens.append(tw)
	return tw


## Through the Audio autoload, looked up at run time (scripts run with --script load before it).
func _sfx(key: String, pitch := 1.0) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.sfx(key, 0.0, pitch)
