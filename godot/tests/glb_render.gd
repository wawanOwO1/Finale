extends SceneTree
## Windowed: render APIS + TONY in rest pose and with a posed arm/head, save PNG to user://glb_render.png.

func _initialize() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 0.55, 2.6)
	cam.rotation_degrees.x = -2.0
	var sun := DirectionalLight3D.new()
	world.add_child(sun)
	sun.rotation_degrees = Vector3(-40, 30, 0)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	world.add_child(env)
	var x := -1.05
	for path in ["res://assets/characters/apis.glb", "res://assets/characters/tony.glb"]:
		for posed in [false, true]:
			var c: Node3D = (load(path) as PackedScene).instantiate()
			world.add_child(c)
			c.position.x = x
			x += 0.7
			if posed:
				var s: Skeleton3D = c.find_children("*", "Skeleton3D", true, false)[0]
				var arm := s.find_bone("mixamorig_RightArm")
				s.set_bone_pose_rotation(arm, s.get_bone_rest(arm).basis.get_rotation_quaternion() * Quaternion(Vector3(0, 0, 1), deg_to_rad(-70)))
				var head := s.find_bone("mixamorig_Head")
				s.set_bone_pose_rotation(head, s.get_bone_rest(head).basis.get_rotation_quaternion() * Quaternion(Vector3(0, 1, 0), deg_to_rad(35)))
				var leg := s.find_bone("mixamorig_LeftUpLeg")
				s.set_bone_pose_rotation(leg, s.get_bone_rest(leg).basis.get_rotation_quaternion() * Quaternion(Vector3(1, 0, 0), deg_to_rad(-40)))
	for i in 10:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("user://glb_render.png")
	print("saved ", ProjectSettings.globalize_path("user://glb_render.png"))
	quit()
