extends SceneTree
## Windowed: render APIS (top row) and TONY (bottom row) in each chef clip at a key moment.
## Saves user://glb_render.png. Columns: idle, chop (impact), busy (left reach), victory (end), lose (end).

const SHOTS := [["idle", 1.0], ["chop", 0.17], ["busy", 0.55], ["victory", 99.0], ["lose", 99.0]]

func _initialize() -> void:
	var world := Node3D.new()
	get_root().add_child(world)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.3
	cam.position = Vector3(0, 1.0, 4.0)
	world.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	world.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	world.add_child(env)
	var row := 0
	for path in ["res://assets/characters/apis.glb", "res://assets/characters/tony.glb"]:
		for i in SHOTS.size():
			var c: Node3D = (load(path) as PackedScene).instantiate()
			world.add_child(c)
			c.position = Vector3(-1.6 + i * 0.8, 1.05 - row * 1.05, 0)
			var ap: AnimationPlayer = c.find_children("*", "AnimationPlayer", true, false)[0]
			ap.play(SHOTS[i][0])
			ap.seek(minf(SHOTS[i][1], ap.current_animation_length), true)
			ap.pause()
		row += 1
	for i in 10:
		await process_frame
	get_root().get_texture().get_image().save_png("user://glb_render.png")
	print("saved ", ProjectSettings.globalize_path("user://glb_render.png"))
	quit()
