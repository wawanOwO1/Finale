extends SceneTree
## Headless: load the character GLBs and check skeleton, mesh and the 5 chef clips (ANIMATION_DESIGN.md).

const CLIPS := {"idle": true, "chop": true, "busy": true, "victory": false, "lose": false}  # name -> loops

func _init() -> void:
	var failed := false
	for path in ["res://assets/characters/apis.glb", "res://assets/characters/tony.glb"]:
		var root: Node = (load(path) as PackedScene).instantiate()
		var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		var mesh: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
		var ap: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false)[0]
		print("== %s  bones=%d  mesh=%s skinned=%s  clips=%s" % [path, skel.get_bone_count(), mesh.name, mesh.skin != null, ap.get_animation_list()])
		for clip in CLIPS:
			if not ap.has_animation(clip):
				print("  FAIL missing ", clip); failed = true; continue
			var a := ap.get_animation(clip)
			var loops := a.loop_mode != Animation.LOOP_NONE
			var ok: bool = loops == CLIPS[clip]
			failed = failed or not ok
			print("  %s %-8s %.2fs tracks=%d loop=%s" % ["ok  " if ok else "FAIL", clip, a.length, a.get_track_count(), loops])
		root.free()
	print("RESULT ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
