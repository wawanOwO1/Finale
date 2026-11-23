extends SceneTree
## Headless: load the character GLBs, report skeleton/mesh/bounds, and pose a bone to prove skinning works.

func _init() -> void:
	for path in ["res://assets/characters/apis.glb", "res://assets/characters/tony.glb"]:
		var ps: PackedScene = load(path)
		if ps == null:
			print("FAIL load ", path); continue
		var root := ps.instantiate()
		get_root().add_child(root)
		var skels := root.find_children("*", "Skeleton3D", true, false)
		var meshes := root.find_children("*", "MeshInstance3D", true, false)
		print("== ", path, " root=", root.get_class(), " skeletons=", skels.size(), " meshes=", meshes.size())
		for s: Skeleton3D in skels:
			print("  bones: ", s.get_concatenated_bone_names().substr(0, 140)); print("  skel global=", s.global_transform); print("  skeleton ", s.name, " bones=", s.get_bone_count(), " profile-ready Hips=", s.find_bone("Hips"), " mixamorig_Hips=", s.find_bone("mixamorig_Hips"))
			var gt := s.global_transform
			var head := s.find_bone("Head") if s.find_bone("Head") >= 0 else s.find_bone("mixamorig_Head")
			var foot := s.find_bone("LeftFoot") if s.find_bone("LeftFoot") >= 0 else s.find_bone("mixamorig_LeftFoot")
			var lh := s.find_bone("LeftHand") if s.find_bone("LeftHand") >= 0 else s.find_bone("mixamorig_LeftHand")
			var rh := s.find_bone("RightHand") if s.find_bone("RightHand") >= 0 else s.find_bone("mixamorig_RightHand")
			print("  head y=%.3f  foot y=%.3f  L hand=%s  R hand=%s" % [(gt * s.get_bone_global_rest(head).origin).y, (gt * s.get_bone_global_rest(foot).origin).y, s.get_bone_global_rest(lh).origin, s.get_bone_global_rest(rh).origin])
		for m: MeshInstance3D in meshes:
			var aabb := m.get_aabb()
			print("  mesh ", m.name, " skin=", m.skin != null, " surfaces=", m.mesh.get_surface_count(), " aabb pos=", aabb.position, " size=", aabb.size, " mat=", m.mesh.surface_get_material(0))
		var aps := root.find_children("*", "AnimationPlayer", true, false)
		print("  animation players=", aps.size())
		root.queue_free()
	quit()
