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
	await _wait(1.0)
	_check("duel started after clicking the book button", main.duel != null)
	_shot("2_intro_countdown")
	await _wait(1.3)
	_shot("2_intro_fight")
	await _wait(3.4)
	_check("intro announcer finished", not ui._announcer.visible)
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

	# Drag the first playable ingredient onto station 2.
	var ing: CardView = null
	for v: CardView in ui._views:
		if v.card.def.is_ingredient() and duel.can_play(v.card.uid).ok:
			ing = v
			break
	if ing:
		var before := duel.stack(1).size()
		await _drag(_card_point(ing), ui._cols[1].get_global_rect().get_center(), "4_dragging_ingredient")
		await _wait(0.5)
		_check("ingredient dragged onto station 2 lands there", duel.stack(1).size() == before + 1)
		# Move it to station 3 by dragging the top card.
		var top: Rect2 = ui._top_card_rect(1)
		await _drag(top.get_center(), ui._cols[2].get_global_rect().get_center(), "4b_moving_top_card")
		await _wait(0.4)
		_check("top card dragged to station 3 moves there", duel.stack(2).size() == 1 and duel.moved_this_turn)
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
	# Fill station 1 with a known dish to show the ticket, then serve it with its button.
	duel.stations[0] = _inst(duel, ["bread", "beef", "cheese"])
	duel.changed.emit()
	await _wait(0.3)
	_shot("5b_stations")
	_crop("5c_stations", Rect2(0.0, 0.15, 0.5, 0.75))
	if duel.can_serve(2).ok:
		await _click(_serve_button(ui, 2).get_global_rect().get_center())
		await _wait(0.35)
		_shot("6_served")
		_crop("6a_served", Rect2(0.0, 0.1, 0.75, 0.45))
		_check("serve button serves", duel.served_this_turn)
	await _wait(0.6)
	# Turn sequence (GRAND_DESIGN §1): RIVAL'S TURN banner → paced steps → YOUR TURN banner.
	await _click(ui.get_node("%EndTurn").get_global_rect().get_center())
	await _wait(0.4)
	_check("end turn hands over to the rival", duel.phase == "enemy" and duel.turn == 1)
	_check("input is locked on the rival turn", ui._locked() and ui.get_node("%EndTurn").disabled)
	_shot("7_rival_banner")
	await _wait(1.3)
	_shot("7b_rival_acting")
	var t0 := Time.get_ticks_msec()
	while duel.phase == "enemy" and Time.get_ticks_msec() - t0 < 12000:
		await _wait(0.1)
	_shot("7c_your_turn_banner")
	var normal_ms := Time.get_ticks_msec() - t0 + 1700
	_check("rival turn is paced (2-8 s): %d ms" % normal_ms, normal_ms > 2000 and normal_ms < 8000)
	await _wait(1.6)
	_check("end turn button advances the turn", duel.turn == 2)
	_check("input unlocks on the player's turn", not ui._locked())
	# Fast-forward: hold Space through a whole rival turn.
	await _click(ui.get_node("%EndTurn").get_global_rect().get_center())
	_space(true)
	var t1 := Time.get_ticks_msec()
	await _wait(0.3)
	_check("holding Space speeds the rival up", Engine.time_scale > 1.0)
	while duel.phase == "enemy" and Time.get_ticks_msec() - t1 < 12000:
		await _wait(0.05)
	_space(false)
	var fast_ms := Time.get_ticks_msec() - t1
	_check("fast-forward is quicker: %d vs %d ms" % [fast_ms, normal_ms], fast_ms < normal_ms * 0.7)
	await _wait(1.6)
	_check("time scale back to normal", Engine.time_scale == 1.0)
	_shot("7_turn2")
	_crop("7a_player_hud", Rect2(0, 0.72, 0.4, 0.28))
	_crop("7b_rival", Rect2(0.5, 0.0, 0.3, 0.25))
	# Signature Dish cut-in
	ui._play_cutin("Omelette")
	await _wait(0.5)
	_shot("8_cutin")
	await _wait(1.4)
	# Emote
	ui._emote.pop("smug")
	await _wait(0.4)
	_crop("8b_emote", Rect2(0.45, 0.0, 0.4, 0.4))
	# Win: emote Sad, FINISHED, YOU WINS!, then the overlay
	duel._lose_confidence("enemy", 999, "pressure")
	duel.changed.emit()
	await _wait(1.0)
	_shot("9a_finished")
	await _wait(1.2)
	_shot("9b_you_wins")
	await _wait(2.2)
	_check("victory overlay shows after the announcer", ui.get_node("%Overlay").visible)
	_shot("9_victory")
	_end()


func _end() -> void:
	print("UI DRIVE: %s" % ("all checks passed" if failures == 0 else "%d failed" % failures))
	quit(1 if failures else 0)


func _check(label: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print("%s  %s" % ["PASS" if ok else "FAIL", label])


func _inst(duel: Duel, ids: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in ids.size():
		out.append(CardInstance.new(90000 + i, GameDB.card(ids[i])))
	return out


func _serve_button(ui: Node, station: int) -> Button:
	for b in ui._cols[station].find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Serve"):
			return b
	return null


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


func _space(down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SPACE
	e.physical_keycode = KEY_SPACE
	e.pressed = down
	Input.parse_input_event(e)
