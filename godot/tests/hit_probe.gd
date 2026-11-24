extends SceneTree
## Hit-test probe: for every HUD button, moves the (simulated) mouse over a grid of points inside
## the button's drawn rect and checks the GUI really hovers that button. Catches invisible
## controls covering part of a button and layout/input mismatches after a resize.
## Run (needs a window):
##   godot --path godot --resolution 1600x900 --script res://tests/hit_probe.gd

var failures := 0


func _initialize() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.dev_deck = true
	main.get_node("AlmanacKeeper").persist = false
	root.add_child(main)
	await _wait(1.5)
	var ui = main.get_node("DuelUI")
	print("window %s  canvas %s" % [root.size, ui.get_node("%Root").size])
	await _probe(ui.get_node("%StartButton"))
	await _click(ui.get_node("%StartButton").get_global_rect().get_center())
	# VS screen first (FX_MASTERPLAN.md §6.4), then the countdown.
	await _wait(0.3)
	while ui.get_node("%VsIntro").visible:
		await _wait(0.05)
	await _wait(5.0)  # 3·2·1 FIGHT! intro
	# Give station 1 a card so its Serve / Clear buttons exist.
	var c := CardInstance.new(90000, GameDB.card("bread"))
	main.duel.stack(0).append(c)
	main.duel.changed.emit()
	await _wait(0.3)
	for b in _buttons(ui):
		await _probe(b)
	# Resize the window at runtime, like dragging its border or toggling fullscreen.
	for sz in [Vector2i(1280, 720), Vector2i(1700, 1000), Vector2i(1000, 900)]:
		root.size = sz
		await _wait(0.5)
		print("-- resized: window %s  canvas %s" % [root.size, ui.get_node("%Root").size])
		for b in _buttons(ui):
			await _probe(b)
	print("HIT PROBE: %s" % ("all buttons fully clickable" if failures == 0 else "%d misses" % failures))
	quit(1 if failures else 0)


## End Turn, pixel toggle and every station button (Serve, Clear).
func _buttons(ui: Node) -> Array[Control]:
	var out: Array[Control] = [ui.get_node("%EndTurn"), ui.get_node("%PixelButton")]
	for col in ui._cols:
		for b in col.find_children("*", "Button", true, false):
			out.append(b)
	return out


func _probe(b: Control) -> void:
	var r := b.get_global_rect().grow(-3)
	var misses: Array = []
	for iy in 5:
		for ix in 7:
			var p := r.position + r.size * Vector2(ix / 6.0, iy / 4.0)
			await _move(p)
			var h := root.gui_get_hovered_control()
			if h != b and (h == null or not b.is_ancestor_of(h)):
				misses.append("%s→%s" % [p.round(), h.name if h else "null"])
	failures += misses.size()
	print("%s  %s rect=%s  %s" % ["PASS" if misses.is_empty() else "FAIL", b.name, b.get_global_rect(),
			"" if misses.is_empty() else str(misses)])


func _wait(t: float) -> void:
	await create_timer(t).timeout


## Events go in as window pixels (what the OS sends), so the stretch transform is exercised.
func _px(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _px(p)
	e.global_position = e.position
	root.push_input(e, false)
	await process_frame
	await process_frame


func _click(p: Vector2) -> void:
	await _move(p)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = _px(p)
		e.global_position = e.position
		root.push_input(e, false)
		await process_frame
