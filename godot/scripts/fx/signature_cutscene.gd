class_name SignatureCutscene
extends FxCutscene
## Apis's Signature Dish cutscene (FX_MASTERPLAN.md §6.2). A node in main.tscn; FxDirector starts it
## when the Signature is served. The duel has already applied the dish: this is only the show.
##
## Beats (AnimationPlayer "long" / "short"): open → close-up → chop ×2 → impact → close.
## The close-up freezes the world (HitStop.cutscene_factor), so the damage numbers, the announcer and
## the rival wait for the impact beat, where FxDirector releases every held cue together. Apis keeps
## moving (Chef.set_anim_speed) and so does the cut-in banner (it tweens on real time).
## Long version once per session (long_once), the short one after that.

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
@export_range(10.0, 80.0, 0.5) var cam_fov := 34.0
## Words slammed during the chop beat, one per chop.
@export var chop_words: PackedStringArray = ["SLASH!", "SLASH!!"]
@export var chop_color := Color("#f2b632")

## FX Quality Low: always the short version.
var force_short := false
var _long_done := false
var _dish := ""
var _impacted := false
var _chops := 0


func _ready() -> void:
	if skip_beat == "":
		skip_beat = "_beat_impact"


func play(dish: String) -> void:
	_dish = dish
	_impacted = false
	_chops = 0
	var v := "short" if force_short or (long_once and _long_done) else "long"
	_long_done = true
	fx.hold = true
	ui.set_busy(true)
	start(v)


# ---------------------------------------------------------------- beats (AnimationPlayer keys)

## Freeze the world, bars in, color drains, cut-in banner slams.
func _beat_open() -> void:
	fx.hit_stop.cutscene_factor = hold_scale
	fx.play_now(open_cue, ui.hit_point("player"))
	ui.play_cutin(_dish)
	_letterbox(true)
	_sfx("signature")


## Cut to the low-angle camera on Apis; the cut-in and the HUD fade out.
func _beat_closeup() -> void:
	var len := beat_time("_beat_impact") - beat_time("_beat_closeup")
	_move_camera(_marker(cam_from_path), _marker(cam_to_path), len, cam_fov, cam_fov)
	ui.end_cutin(0.12)
	_fade_hud(0.0)
	stage.player.set_anim_speed(1.0 / maxf(0.001, Engine.time_scale))


## One knife hit: chop clip, a word, a chop sound. Keyed more than once.
func _beat_chop() -> void:
	stage.player.perform("chop")
	var n := _chops
	_chops += 1
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


func _beat_close() -> void:
	close()


func _on_close() -> void:
	if not _impacted:
		_beat_impact()


func _on_abort() -> void:
	stage.player.set_anim_speed(1.0)
