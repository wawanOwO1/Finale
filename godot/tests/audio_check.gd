extends SceneTree
## Headless audio wiring check: every file loads, menu/deck/battle loop, duel events play SFX.
## Run:  godot --headless --path godot --script res://tests/audio_check.gd

var failures := 0


func _initialize() -> void:
	await process_frame
	var audio: Node = root.get_node_or_null("Audio")
	_check("Audio autoload exists", audio != null)
	if audio == null:
		return _end()
	for k in audio.MUSIC:
		_check("music %s loaded" % k, audio.MUSIC[k] is AudioStreamMP3)
	for k in ["menu", "deck", "battle"]:
		_check("music %s loops" % k, audio.MUSIC[k].loop)
	for k in audio.SFX:
		_check("sfx %s loaded" % k, audio.SFX[k] is AudioStreamMP3 and audio.SFX[k].get_length() > 0.0)

	# Normal rival -> Battle_Theme + Round start.
	var duel := Duel.new(GameDB.deck("dev"), GameDB.enemy("tony"), GameDB.book_recipes(GameDB.ALL_BOOKS), {seed = 7})
	audio.bind(duel)
	_check("normal duel plays battle theme", audio._music_key == "battle")
	_check("round start sfx", _playing(audio, "round_start"))
	var ing := -1
	for c in duel.hand:
		if c.def.is_ingredient():
			ing = c.uid
			break
	if ing >= 0:
		duel.play(ing)
		_check("ingredient -> chopping", _playing(audio, "chop"))
		duel.serve()
		_check("serve -> pot", _playing(audio, "pot"))
		await create_timer(0.3).timeout
		_check("serve -> bell", _playing(audio, "bell"))
	duel.end_turn(); duel.run_enemy_turn()
	_check("new turn -> turn change", _playing(audio, "turn"))
	duel.duel_ended.emit("player")
	_check("win -> victory music", audio._music_key == "victory")
	_check("win -> round won sfx", _playing(audio, "round_won"))

	# Boss rival -> no Battle_Theme, boss sting.
	var boss_def: EnemyDef = GameDB.enemy("tony").duplicate()
	boss_def.boss = true
	audio.bind(Duel.new(GameDB.deck("starter"), boss_def, GameDB.book_recipes(["basics"]), {seed = 3}))
	_check("boss duel skips battle theme", audio._music_key == "")
	_check("boss sting", _playing(audio, "boss"))
	_end()


func _playing(audio: Node, key: String) -> bool:
	for v: AudioStreamPlayer in audio._voices:
		if v.playing and v.stream == audio.SFX[key]:
			return true
	return false


func _check(what: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print(("  ok   " if ok else "  FAIL ") + what)


func _end() -> void:
	print("audio_check: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures else 0)
