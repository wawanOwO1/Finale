extends SceneTree
## Windowed tool: renders the VS-screen portraits (FX_MASTERPLAN.md §6.4) from the character GLBs,
## so the intro is a 2D picture and never a second live 3D render on the web.
## Writes res://assets/portraits/<id>.png (transparent, 360x420). Re-run after a model changes:
##   godot --path godot --script res://tests/portrait_render.gd

## [id, clip, time]: a pose with some energy, one per character in assets/characters/.
const POSES := [["apis", "chop", 0.8], ["tony", "chop", 0.8]]
const SIZE := Vector2i(360, 420)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/portraits"))
	for pose in POSES:
		await _render(pose[0], pose[1], pose[2])
	quit()


func _render(id: String, clip: String, t: float) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	get_root().add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.7, 0.65)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, -35, 0)
	sun.light_color = Color("#fff1d6")
	world.add_child(sun)
	var c: Node3D = (load("res://assets/characters/%s.glb" % id) as PackedScene).instantiate()
	world.add_child(c)
	var ap: AnimationPlayer = c.find_children("*", "AnimationPlayer", true, false)[0]
	if ap.has_animation(clip):
		ap.play(clip)
		ap.seek(minf(t, ap.current_animation_length), true)
		ap.pause()
	var cam := Camera3D.new()
	cam.fov = 30.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0.25, 0.76, 1.55), Vector3(0, 0.64, 0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://assets/portraits/%s.png" % id
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved ", path)
	vp.queue_free()
