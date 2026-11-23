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
	# Fresh Almanac each run, never the player's own save.
	var keeper: AlmanacKeeper = main.get_node("AlmanacKeeper")
	keeper.save_path = out_dir.path_join("almanac_test.save")
	DirAccess.remove_absolute(keeper.save_path)
	root.add_child(main)
	await _wait(0.6)
	_shot("1_cookbook")
	_crop("1a_cookbook", Rect2(0.2, 0.1, 0.6, 0.6))
	var ui = main.get_node("DuelUI")
	# Almanac from the Recipe Book (GRAND_DESIGN §6.4): always opens before the duel.
	await _click(ui.get_node("%BookAlmanac").get_global_rect().get_center())
	await _wait(0.3)
	_check("Almanac opens from the Recipe Book", ui.get_node("%Almanac").visible and paused)
	_check("your deck is already in it", keeper.almanac.knows_card("bread") and keeper.almanac.knows_recipe("toast"))
	_shot("1b_almanac")
	_key(KEY_TAB)
	await _wait(0.2)
	_check("Tab closes it and unpauses", not ui.get_node("%Almanac").visible and not paused)
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
	_crop("2b_board_rival", Rect2(0.0, 0.0, 1.0, 0.5))

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
		# Move it to station 1 by dragging the top card.
		var before0 := duel.stack(0).size()
		var top: Rect2 = ui._top_card_rect(1)
		await _drag(top.get_center(), ui._cols[0].get_global_rect().get_center(), "4b_moving_top_card")
		await _wait(0.4)
		_check("top card dragged to station 1 moves there", duel.stack(0).size() == before0 + 1 and duel.moved_this_turn)
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
	if duel.can_serve(0).ok:
		await _click(_serve_button(ui, 0).get_global_rect().get_center())
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
	# Drafting rival (GRAND_DESIGN §3.5): face-down stations, never a card face.
	var rk: Control = ui.get_node("%RivalKitchen")
	_check("rival kitchen shows for a drafting rival", rk.visible and duel.drafting())
	_check("rival cards are never drawn face up", rk.find_children("*", "CardView", true, false).is_empty())
	_crop("7d_rival_kitchen", Rect2(0.55, 0.15, 0.4, 0.45))
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
	_crop("7b_rival", Rect2(0.75, 0.08, 0.25, 0.32))
	# Chef's Flow (GRAND_DESIGN §5): one Perfect Serve short, then a Perfect Toast opens the pick.
	var pk := duel.kitchen("player")
	pk.flow = pk.flow_threshold() - 1
	duel.stations[0] = _inst(duel, ["bread", "butter"])
	duel.changed.emit()
	await _wait(0.3)
	await _click(_serve_button(ui, 0).get_global_rect().get_center())
	await _wait(1.0)
	_check("the pick waits for the dish reveal", not ui.get_node("%FlowPick").visible)
	await _wait(0.9)
	var pick: Control = ui.get_node("%FlowPick")
	var cards := ui.get_node("%FlowChoices").get_children()
	_check("Chef's Flow opens a pick of 3", pick.visible and cards.size() == 3)
	_check("input is locked while picking", ui._locked() and not duel.end_turn().ok)
	_shot("7e_flow_pick")
	var chosen: String = pk.offer[1].id
	await _click((cards[1] as Control).get_global_rect().get_center())
	await _wait(0.3)
	_check("clicking a card takes that modifier", pk.mod(chosen) == 1 and not pick.visible and not ui._locked())
	_check("the HUD shows the modifier", ui.get_node("%PlayerFlow").get_child_count() >= 2)
	await _wait(1.2)
	_crop("7f_player_flow", Rect2(0, 0.62, 0.4, 0.38))
	# Almanac mid-duel (GRAND_DESIGN §6.4): the HUD book button pauses the duel.
	var alm: Control = ui.get_node("%Almanac")
	await _click(ui.get_node("%AlmanacButton").get_global_rect().get_center())
	await _wait(0.3)
	_check("HUD book button opens the Almanac and pauses", alm.visible and paused)
	_check("input is locked while it is open", ui._locked())
	await _click(ui.get_node("%AlmanacTabs/Recipes").get_global_rect().get_center())
	await _wait(0.2)
	await _click(ui.get_node("%FinderChips/SPICE").get_global_rect().get_center())
	await _wait(0.2)
	var known: Array[RecipeDef] = []
	for r: RecipeDef in GameDB.all("recipes"):
		if keeper.almanac.knows_recipe(r.id):
			known.append(r)
	var rows := ui.get_node("%AlmanacList").get_children().filter(func(n: Node) -> bool: return n.has_meta("key"))
	var want := Almanac.find(known, ["SPICE"]).size()
	_check("finder chip filters the recipes: %d rows, want %d" % [rows.size(), want], want > 0 and rows.size() == want)
	_shot("7g_almanac_finder")
	await _click(ui.get_node("%AlmanacTabs/Rivals").get_global_rect().get_center())
	await _wait(0.2)
	var tile: Control = ui.get_node("%AlmanacList").find_child("tony", true, false)
	if tile:
		await _click(tile.get_global_rect().get_center())
		await _wait(0.2)
	var texts := ui.get_node("%DetailBox").find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	_check("rival tile shows Tony in the detail", texts.has("Tony"))
	_shot("7h_almanac_rival")
	await _click(ui.get_node("%AlmanacClose").get_global_rect().get_center())
	await _wait(0.2)
	_check("Close unpauses and unlocks", not alm.visible and not paused and not ui._locked())
	# On the rival's turn Tab only queues it: it opens when the player's turn starts.
	await _click(ui.get_node("%EndTurn").get_global_rect().get_center())
	await _wait(0.4)
	_key(KEY_TAB)
	await _wait(0.2)
	_check("Tab on the rival turn waits", duel.phase == "enemy" and not alm.visible and ui._almanac_queued)
	var t2 := Time.get_ticks_msec()
	while not alm.visible and Time.get_ticks_msec() - t2 < 14000:
		await _wait(0.1)
	if not (alm.visible and paused):
		print("  diag: visible=%s paused=%s " % [alm.visible, paused] + "phase=%s busy=%s running=%s announcer=%s drag=%s sdrag=%s over=%s queued=%s flow=%s" % [duel.phase, ui._busy, ui.director.running, ui._announcer.visible, ui._drag, ui._sdrag, duel.over(), ui._almanac_queued, ui.get_node("%FlowPick").visible])
	_check("queued Almanac opens on the player's turn", alm.visible and paused and duel.phase == "player")
	_key(KEY_ESCAPE)
	await _wait(0.2)
	_check("Esc closes it", not alm.visible and not paused)
	# Signature Dish cut-in
	ui._play_cutin("player", "Omelette")
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
		if (b as Button).text.to_lower().begins_with("serve"):
			return b
	return null


func _card_point(v: CardView) -> Vector2:
	var r := v.visual_rect()
	return r.position + Vector2(r.size.x / 2.0, r.size.y * 0.3)


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


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		root.push_input(e)
