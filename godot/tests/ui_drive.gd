extends SceneTree
## UI smoke test with real (simulated) mouse input: opens main.tscn, closes the Recipe Book,
## drags an ingredient onto the Prep Board, drags a technique up, serves, saves screenshots.
## Run (needs a window, not --headless):
##   godot --path godot --resolution 1600x900 --script res://tests/ui_drive.gd -- <out_dir>

var out_dir := ""
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.dev_deck = true
	root.add_child(main)
	await _wait(0.6)
	_shot("1_cookbook")
	_crop("1a_cookbook", Rect2(0.2, 0.1, 0.6, 0.6))
	var ui = main.get_node("DuelUI")
	await _click(ui.get_node("%StartButton").get_global_rect().get_center())
	await _wait(0.8)
	_check("duel started after clicking the book button", main.duel != null)
	if main.duel == null:
		return _end()
	var duel: Duel = main.duel
	_shot("2_duel")
	_crop("2a_player_hud", Rect2(0, 0.72, 0.4, 0.28))
	_crop("2b_board_rival", Rect2(0.05, 0.0, 0.65, 0.45))

	# Hover the middle card: it should lift.
	var views: Array = ui._views
	var mid: CardView = views[views.size() / 2]
	await _move(mid.get_global_rect().get_center() + Vector2(0, 40))
	await _wait(0.3)
	_check("hovering lifts a card", mid.hovered)
	_shot("3_hover")
	_crop("3a_hover", Rect2(0.25, 0.45, 0.5, 0.55))

	# Drag the first playable ingredient onto the Prep Board.
	var ing: CardView = null
	for v: CardView in ui._views:
		if v.card.def.is_ingredient() and duel.can_play(v.card.uid).ok:
			ing = v
			break
	if ing:
		var plate_before := duel.plate.size()
		var board: Control = ui.get_node("%Board")
		await _drag(_card_point(ing), board.get_global_rect().get_center(), "4_dragging_ingredient")
		await _wait(0.5)
		_check("ingredient dragged onto the board lands on the Plate", duel.plate.size() == plate_before + 1)
	# Drag a technique up into the play zone.
	var tech: CardView = null
	for v: CardView in ui._views:
		if not v.card.def.is_ingredient() and duel.can_play(v.card.uid).ok:
			tech = v
			break
	if tech:
		var hand_before := duel.hand.size()
		await _drag(_card_point(tech), Vector2(960, 300), "5_dragging_technique")
		await _wait(0.5)
		_check("technique dragged up is played", duel.hand.size() == hand_before - 1)
	# A plain click on a card only shows the hint.
	if ui._views.size() > 0:
		var n := duel.hand.size()
		await _click(_card_point(ui._views[0]))
		await _wait(0.2)
		_check("plain click does not play a card", duel.hand.size() == n)
	# Serve
	if duel.can_serve().ok:
		await _click(ui.get_node("%ServeButton").get_global_rect().get_center())
		await _wait(0.35)
		_shot("6_served")
		_crop("6a_served", Rect2(0.0, 0.1, 0.75, 0.45))
		_check("serve button serves", duel.served_this_turn)
	await _wait(0.6)
	await _click(ui.get_node("%EndTurn").get_global_rect().get_center())
	await _wait(0.6)
	_check("end turn button advances the turn", duel.turn == 2)
	_shot("7_turn2")
	_crop("7a_player_hud", Rect2(0, 0.72, 0.4, 0.28))
	_crop("7b_rival", Rect2(0.5, 0.0, 0.3, 0.25))
	# Signature Dish cut-in
	ui._play_cutin("Omelette")
	await _wait(0.5)
	_shot("8_cutin")
	await _wait(1.4)
	# Win screen
	duel._lose_confidence("enemy", 999, "pressure")
	duel.changed.emit()
	await _wait(0.5)
	_check("victory overlay shows", ui.get_node("%Overlay").visible)
	_shot("9_victory")
	_end()


func _end() -> void:
	print("UI DRIVE: %s" % ("all checks passed" if failures == 0 else "%d failed" % failures))
	quit(1 if failures else 0)


func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", label])


func _card_point(v: CardView) -> Vector2:
	return v.home_pos + Vector2(v.size.x / 2.0, v.size.y * 0.3)


func _wait(t: float) -> void:
	await create_timer(t).timeout


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	root.push_input(e, true)
	await process_frame


func _button(p: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	e.global_position = p
	root.push_input(e, true)
	await process_frame


func _click(p: Vector2) -> void:
	await _move(p)
	await _wait(0.05)
	await _button(p, true)
	await _button(p, false)


func _drag(from: Vector2, to: Vector2, shot := "") -> void:
	await _move(from)
	await _wait(0.25)
	await _button(from, true)
	for i in range(1, 13):
		await _move(from.lerp(to, i / 12.0))
	await _wait(0.05)
	if shot != "":
		_shot(shot)
	await _button(to, false)


func _shot(name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


## Save a region (fractions of the window) at full resolution, for close inspection.
func _crop(name: String, f: Rect2) -> void:
	var img := root.get_texture().get_image()
	var sz := Vector2(img.get_size())
	var r := Rect2i(Vector2i(f.position * sz), Vector2i(f.size * sz))
	img.get_region(r).save_png(out_dir.path_join(name + ".png"))
