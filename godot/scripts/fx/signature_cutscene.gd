class_name SignatureCutscene
extends Node
## Apis's Signature Dish cutscene (FX_MASTERPLAN.md §6.2). A node in main.tscn; FxDirector starts it
## when the Signature is served. The duel has already applied the dish: this is only the show.
##
## The beats are method keys in the AnimationPlayer child ("long", "short"): move them in the
## animation editor to retime the scene. The player runs in manual mode, advanced on real time,
## because the close-up freezes the world (HitStop.cutscene_factor): the damage numbers, the
## announcer and the rival wait, and land together on the impact beat. Apis keeps moving
## (Chef.set_anim_speed) and so does the cut-in banner (it tweens on real time).
##
## Long version once per session (long_once), the short one after that. Click, Space or Esc skips
## to the impact. Every beat only touches visuals, so skipping or aborting can never break a duel.

signal finished

## Turn the cutscene off: FxDirector then plays the plain cut-in + signature cue.
@export var enabled := true
## Long version only the first time per session; then the short one.
@export var long_once := true
## World speed during the close-up (0.02 = frozen; numbers and the rival wait for the impact).
@export_range(0.0, 1.0, 0.01) var hold_scale := 0.02
@export_group("Opening")
## Cue played at once, past FxDirector.hold: drained color + focus lines.
@export var open_cue: FxCue
@export_group("Close-up")
## Camera path: CutCamera moves from `cam_from` to `cam_to` (Marker3D in stage.tscn) over the close-up.
@export var cam_from_path := NodePath("CutMarkers/SigFrom")
@export var cam_to_path := NodePath("CutMarkers/SigTo")
## Words slammed during the chop beat, one per chop.
@export var chop_words: PackedStringArray = ["SLASH!", "SLASH!!"]
@export var chop_color := Color("#f2b632")
@export_group("Letterbox & HUD")
## Height of each black bar, design px (1080 high).
@export var letterbox_px := 120.0
## Fade of the HUD out (close-up) and back in (impact), real seconds.
@export_range(0.0, 1.0, 0.01) var hud_fade := 0.15
@export_range(0.05, 1.0, 0.01) var letterbox_time := 0.22

@onready var anim: AnimationPlayer = $AnimationPlayer

var stage: Stage
var ui: DuelUI
var fx: FxDirector
var playing := false
## Which version is running ("long" | "short").
var version := ""
var _long_done := false
var _dish := ""
var _last_ms := 0
var _cam_t := -1.0
var _cam_len := 1.0
var _cam_from: Transform3D
var _cam_to: Transform3D
var _impacted := false
var _tweens: Array[Tween] = []
var _chops := 0


func setup(stage_: Stage, ui_: DuelUI, fx_: FxDirector) -> void:
	stage = stage_
	ui = ui_
	fx = fx_
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	set_process(false)
	_reset_visuals()


func play(dish: String) -> void:
	if playing:
		abort()
	_dish = dish
	version = "short" if long_once and _long_done else "long"
	_long_done = true
	playing = true
	_impacted = false
	fx.hold = true
	ui.set_busy(true)
	_last_ms = Time.get_ticks_msec()
	set_process(true)
	anim.play(version)
	anim.advance(0.0)


## Jump to the impact (input skip). Past it, finish at once.
func skip() -> void:
	if not playing:
		return
	if not _impacted:
		anim.seek(beat_time("_beat_impact") + 0.001, true)
		_beat_impact()
	else:
		_beat_close()


## Stop now and put everything back (new duel, scene change). Held cues are released.
func abort() -> void:
	if not playing:
		return
	if not _impacted:
		_beat_impact()
	_beat_close()
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	_reset_visuals()


## Time of a beat in the running (or long) animation, -1 if missing.
func beat_time(method: String) -> float:
	var a := anim.get_animation(version if version != "" else "long")
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_METHOD:
			continue
		for k in a.track_get_key_count(t):
			if a.method_track_get_name(t, k) == method:
				return a.track_get_key_time(t, k)
	return -1.0


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
	if playing and not anim.is_playing():
		_beat_close()


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


# ---------------------------------------------------------------- beats (AnimationPlayer keys)

## Freeze the world, bars in, color drains, cut-in banner slams.
func _beat_open() -> void:
	fx.hit_stop.cutscene_factor = hold_scale
	fx.play_now(open_cue, ui.hit_point("player"))
	ui.play_cutin(_dish)
	_letterbox(true)
	_sfx("signature")


## Cut to the low-angle camera on Apis; the HUD fades out.
func _beat_closeup() -> void:
	var from := stage.get_node_or_null(cam_from_path) as Node3D
	var to := stage.get_node_or_null(cam_to_path) as Node3D
	if from == null or to == null:
		return
	_cam_from = from.global_transform
	_cam_to = to.global_transform
	_cam_len = maxf(0.1, beat_time("_beat_impact") - beat_time("_beat_closeup"))
	_cam_t = 0.0
	stage.cut_camera.global_transform = _cam_from
	stage.cut_camera.make_current()
	ui.end_cutin(0.12)
	_fade_hud(0.0)
	stage.player.set_anim_speed(1.0 / maxf(0.001, Engine.time_scale))


## One knife hit: chop clip, a word, a chop sound. Keyed more than once.
func _beat_chop() -> void:
	stage.player.perform("chop")
	var n := _count_chops()
	var word := chop_words[n % chop_words.size()] if chop_words.size() > 0 else ""
	var size := ui.hud_root().size
	var at := Vector2(size.x * (0.3 if n % 2 == 0 else 0.7), size.y * (0.35 + 0.1 * (n % 2)))
	fx.hud.word(word, at, chop_color, 3, true)
	fx.shake.add(0.35)
	_sfx("chop", 1.0 + 0.12 * n)


## Back to the duel camera on the impact frame (the two-tone frames hide the cut), the world
## runs again and every held cue (signature, dish, damage, KO) lands at once.
func _beat_impact() -> void:
	if _impacted:
		return
	_impacted = true
	_cam_t = -1.0
	stage.camera.make_current()
	stage.player.set_anim_speed(1.0)
	fx.hit_stop.cutscene_factor = 1.0
	_fade_hud(1.0, 0.05)
	fx.hud.clear_words()
	fx.release()


## Bars out, input back (unless the Signature ended the duel: the result sequence keeps it locked).
func _beat_close() -> void:
	if not playing:
		return
	playing = false
	set_process(false)
	anim.stop()
	if not _impacted:
		_beat_impact()
	_letterbox(false)
	if ui.duel and not ui.duel.over():
		ui.set_busy(false)
	finished.emit()


# ---------------------------------------------------------------- helpers

## Through the Audio autoload, looked up at run time (scripts run with --script load before it).
func _sfx(key: String, pitch := 1.0) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.sfx(key, 0.0, pitch)


func _count_chops() -> int:
	_chops += 1
	return _chops - 1


func _letterbox(on: bool) -> void:
	var box := ui.letterbox()
	var top: Control = box.get_node("LetterTop")
	var bottom: Control = box.get_node("LetterBottom")
	box.show()
	var tw := _tween()
	var h := letterbox_px
	tw.tween_property(top, "offset_bottom", h if on else 0.0, letterbox_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bottom, "offset_top", -h if on else 0.0, letterbox_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not on:
		tw.tween_callback(box.hide)
		_chops = 0


func _fade_hud(alpha: float, time := -1.0) -> void:
	var tw := _tween()
	tw.tween_property(ui.hud_root(), "modulate:a", alpha, hud_fade if time < 0.0 else time)


## Real-time tweens (they run while the world is frozen).
func _tween() -> Tween:
	var tw := create_tween().set_ignore_time_scale(true)
	_tweens.append(tw)
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid())
	return tw


func _reset_visuals() -> void:
	if ui == null:
		return
	ui.hud_root().modulate.a = 1.0
	var box := ui.letterbox()
	box.hide()
	(box.get_node("LetterTop") as Control).offset_bottom = 0.0
	(box.get_node("LetterBottom") as Control).offset_top = 0.0
