class_name FinishCutscene
extends FxCutscene
## End-of-duel cutscene (FX_MASTERPLAN.md §6.3), before the announcer's FINISHED → YOU WINS! / LOSER.
## FxDirector starts it when the duel ends (after a Signature's impact if that is what ended it);
## DuelUI waits for it before the announcer.
##
## "win": the KO's impact frame (the win cue) is already on screen; the world slows down, the camera
##        glides from the duel view to the beaten rival, the HUD fades, then everything comes back.
## "lose": no impact. The world slows, color drains (the lose cue), the camera sinks onto Apis,
##        the crowd falls still.

## World speed during the slow-mo.
@export_range(0.05, 1.0, 0.01) var win_slowmo := 0.3
@export_range(0.05, 1.0, 0.01) var lose_slowmo := 0.5
@export_group("Camera")
@export var win_marker := NodePath("CutMarkers/KoWin")
@export var lose_marker := NodePath("CutMarkers/KoLose")
@export_range(10.0, 80.0, 0.5) var win_fov := 28.0
@export_range(10.0, 80.0, 0.5) var lose_fov := 30.0

var won := false


func play(won_: bool) -> void:
	won = won_
	ui.set_busy(true)
	start("win" if won else "lose")


# ---------------------------------------------------------------- beats (AnimationPlayer keys)

## Slow-mo, bars in, HUD out, camera starts its glide from exactly the duel view.
func _beat_open() -> void:
	fx.hit_stop.cutscene_factor = win_slowmo if won else lose_slowmo
	_letterbox(true)
	_fade_hud(0.0, 0.25)
	var len := beat_time("_beat_back") - beat_time("_beat_open")
	_move_camera(stage.camera.global_transform, _marker(win_marker if won else lose_marker),
			len, stage.camera.fov, win_fov if won else lose_fov)
	if not won:
		stage.crowd_still = true


## The crowd erupts (win) as the rival hits the floor.
func _beat_react() -> void:
	if won:
		stage.cheer(1.0)
		fx.shake.add(0.4)
	else:
		_sfx("debuff", 0.8)


## Normal speed, duel camera, HUD back: the announcer takes over.
func _beat_back() -> void:
	close()


func _on_close() -> void:
	fx.hit_stop.cutscene_factor = 1.0


func _on_abort() -> void:
	stage.crowd_still = false
