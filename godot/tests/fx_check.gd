extends SceneTree
## Headless FX check (FX_MASTERPLAN.md §10): cue budgets per tier, Duel signal → cue mapping,
## HitStop as the only owner of Engine.time_scale, Shake and the FxScreen overlay.
## Run:  godot --headless --path godot --script res://tests/fx_check.gd

## Max per tier: [hitstop s, trauma, flash alpha].
const BUDGET := [[0.0, 0.15, 0.0], [0.07, 0.35, 0.2], [0.13, 0.6, 0.4], [0.3, 1.0, 0.8]]

var failures := 0


func _initialize() -> void:
	_budgets()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	var keeper: AlmanacKeeper = main.get_node("AlmanacKeeper")
	keeper.save_path = OS.get_user_data_dir().path_join("almanac_fx_check.save")
	root.add_child(main)
	await process_frame
	var fx: FxDirector = main.fx
	for slot in ["serve", "serve_big", "serve_burnt", "big_hit", "signature", "win", "lose"]:
		_check("FxDirector.%s is set" % slot, fx.get(slot) is FxCue)
	_check("TurnDirector goes through HitStop", main.director.hit_stop == fx.hit_stop)
	_check("shake drives the stage camera and the HUD", fx.shake.camera == main.stage.camera and fx.shake.hud == main.ui)
	for i in 4:
		await process_frame
	_check("overlay hidden after prewarm", not fx.screen.visible)

	var duel := Duel.new(GameDB.deck("dev"), GameDB.enemy("tony"), GameDB.book_recipes(GameDB.ALL_BOOKS), {seed = 7})
	fx.bind(duel)
	# TurnDirector resets fast_forward every frame (nobody holds Space here); the test sets it by hand.
	main.director.set_process(false)
	await _hitstop(fx)
	await _mapping(fx, duel)
	await _shake(fx)
	await _real_serve(fx, duel)
	_end()


func _budgets() -> void:
	for f in DirAccess.get_files_at("res://data/fx"):
		if not f.ends_with(".tres"):
			continue
		var c: FxCue = load("res://data/fx/" + f)
		var b: Array = BUDGET[c.tier]
		_check("%s (T%d) inside its budget" % [f, c.tier],
				c.hitstop <= b[0] + 0.0001 and c.trauma <= b[1] + 0.0001 and c.flash <= b[2] + 0.0001)
		_check("%s: only T3 may drain color for long" % f, c.tier == 3 or c.desat_hold <= 0.5)


func _hitstop(fx: FxDirector) -> void:
	var hs := fx.hit_stop
	hs.fast_forward = 1.0
	fx.play(fx.serve_big)
	_check("hitstop slows the game", is_equal_approx(Engine.time_scale, hs.slow_scale))
	_check("flash starts", fx.flash_value() > 0.0 and fx.screen.visible)
	hs.fast_forward = 3.0
	await process_frame
	_check("fast-forward multiplies through a hitstop", is_equal_approx(Engine.time_scale, 3.0 * hs.slow_scale))
	await _real_wait(0.25)
	_check("hitstop ends on real time", is_equal_approx(Engine.time_scale, 3.0))
	hs.fast_forward = 1.0
	await process_frame
	_check("back to normal speed", Engine.time_scale == 1.0)
	_check("flash faded and overlay hidden", fx.flash_value() == 0.0 and not fx.screen.visible)
	# Overlapping requests do not stack.
	hs.request(0.1)
	hs.request(0.1)
	await _real_wait(0.16)
	_check("two hitstops in one frame last as one", not hs.active())


func _mapping(fx: FxDirector, duel: Duel) -> void:
	var expect := func(what: String, cue: FxCue) -> void:
		_check(what, fx.last_cue == cue)
		fx.last_cue = null
		fx.hit_stop.clear()
	duel.dish_served.emit("player", null, 5, 0, 3)
	expect.call("small Serve -> serve", fx.serve)
	duel.dish_served.emit("enemy", null, fx.big_pressure, 0, 3)
	expect.call("Serve >= big_pressure -> serve_big", fx.serve_big)
	duel.dish_revealed.emit("player", null, true, false, false)
	expect.call("Perfect -> serve_big", fx.serve_big)
	duel.dish_revealed.emit("player", null, false, false, true)
	expect.call("Burnt -> serve_burnt", fx.serve_burnt)
	duel.dish_served.emit("player", null, 0, 0, 3)
	expect.call("Serve that is fully blocked -> nothing", null)
	duel.confidence_lost.emit("player", ceili(duel.player.max_confidence * fx.big_hit_ratio), "pressure")
	expect.call("big Confidence loss -> big_hit", fx.big_hit)
	duel.confidence_lost.emit("player", 99, "spicy")
	expect.call("Spicy tick -> nothing", null)
	duel.signature_served.emit("player", "Omelette")
	expect.call("Signature -> signature", fx.signature)
	duel.duel_ended.emit("player")
	expect.call("win -> win", fx.win)
	duel.duel_ended.emit("enemy")
	expect.call("lose -> lose", fx.lose)
	_check("lose drains color", fx.desat_value() > 0.5 and fx.screen.visible)
	# Strongest value wins: a small flash right after a big one does not cut it short.
	fx.play(fx.signature)
	var peak := fx.flash_value()
	fx.play(fx.serve_big)
	_check("weaker flash does not replace a stronger one", fx.flash_value() >= peak * 0.8)
	fx.reduce_flashing = true
	await _real_wait(0.4)
	fx.play(fx.signature)
	_check("Reduce Flashing lowers the flash", fx.flash_value() <= fx.signature.flash * fx.reduce_flash_scale + 0.001)
	fx.reduce_flashing = false
	fx.hit_stop.clear()


func _shake(fx: FxDirector) -> void:
	var s := fx.shake
	s.trauma = 0.0
	s.add(0.8)
	s.add(0.3)
	_check("weaker trauma does not lower a stronger one", is_equal_approx(s.trauma, 0.8))
	var moved := false
	var on_grid := true
	for i in 8:
		await process_frame
		moved = moved or s.camera.h_offset != 0.0 or s.camera.v_offset != 0.0
		on_grid = on_grid and is_zero_approx(fmod(absf(s.hud.offset.x), s.hud_grid)) and is_zero_approx(fmod(absf(s.hud.offset.y), s.hud_grid))
	_check("camera shakes", moved)
	_check("HUD offset stays on the 3 px grid", on_grid)
	await _real_wait(0.8)
	await process_frame
	_check("shake settles back to zero", s.trauma == 0.0 and s.camera.h_offset == 0.0 and s.hud.offset == Vector2.ZERO)


## A real Serve through the Duel API reaches FxDirector.
func _real_serve(fx: FxDirector, duel: Duel) -> void:
	fx.last_cue = null
	for c in duel.hand.duplicate():
		if c.def.is_ingredient():
			duel.play(c.uid)
	duel.serve()
	_check("a real Serve plays a cue", fx.last_cue != null)
	fx.hit_stop.clear()


func _real_wait(seconds: float) -> void:
	await create_timer(seconds, true, false, true).timeout


func _check(what: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _end() -> void:
	Engine.time_scale = 1.0
	print("fx_check: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)
