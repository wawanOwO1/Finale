extends SceneTree
## Chef animation wiring in the real game (ANIMATION_DESIGN.md): opens main.tscn, starts a duel,
## fires duel signals and checks which clip each chef plays. Saves screenshots.
## Run (needs a window, not --headless):
##   godot --path godot --resolution 1600x900 --script res://tests/chef_drive.gd -- <out_dir>

var out_dir := ""
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.pixel_on_start = false
	var keeper: AlmanacKeeper = main.get_node("AlmanacKeeper")
	keeper.save_path = out_dir.path_join("almanac_test.save")
	DirAccess.remove_absolute(keeper.save_path)
	root.add_child(main)
	await _wait(0.6)
	var ui = main.get_node("DuelUI")
	var stage: Stage = main.stage
	var apis: Chef = stage.player
	var tony: Chef = stage.rival
	_check("Apis shows its model", apis.has_model() and not apis.get_node("Placeholder").visible)
	_check("Tony shows its model", tony.has_model() and tony.get_node("tony").visible)
	await _click(ui.get_node("%StartButton").get_global_rect().get_center())
	await _wait(5.5)
	var duel: Duel = main.duel
	if duel == null:
		_check("duel started", false)
		return _end()
	_check("both chefs idle at the start", apis.current_clip() == "idle" and tony.current_clip() == "idle")
	await _shot("chef_1_idle")

	var card: CardInstance = duel.hand[0]
	duel.card_played.emit("player", card)
	duel.card_played.emit("enemy", card)
	await _wait(0.35)
	_check("card played → both chefs chop", apis.current_clip() == "chop" and tony.current_clip() == "chop")
	await _shot("chef_2_chop")
	await _wait(1.3)
	_check("chop returns to idle", apis.current_clip() == "idle" and tony.current_clip() == "idle")

	duel.dish_served.emit("enemy", null, 0, 0, 0)
	await _wait(0.5)
	_check("rival serves → Tony busy", tony.current_clip() == "busy" and apis.current_clip() == "idle")
	await _shot("chef_3_busy")
	await _wait(2.6)

	duel.duel_ended.emit("player")
	await _wait(0.3)
	_check("duel won → Apis victory, Tony lose", apis.current_clip() == "victory" and tony.current_clip() == "lose")
	duel.card_played.emit("player", card)
	await _wait(0.1)
	_check("nothing interrupts the end pose", apis.current_clip() == "victory")
	await _wait(2.6)
	await _shot("chef_4_end")

	tony.character = "rosa"
	await _wait(0.1)
	_check("rival without a model falls back to the placeholder",
			not tony.has_model() and tony.get_node("Placeholder").visible and not tony.get_node("tony").visible)
	_end()


func _end() -> void:
	print("RESULT ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		failures += 1


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _shot(name: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _click(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	root.push_input(m, true)
	await _wait(0.05)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		root.push_input(e, true)
		await process_frame
