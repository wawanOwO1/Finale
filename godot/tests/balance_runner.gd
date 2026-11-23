extends RefCounted
## Bots for balancing (GRAND_DESIGN §8, phase G), shared by tests/balance.gd and tests/sim.gd.
## "smart" = RivalAI playing Apis's side (close to a careful human), "simple" = plays random
## playable cards and serves any finished dish (a new player).
## Use: const Bots := preload("res://tests/balance_runner.gd"); Bots.run(enemy, "smart", 300, {})

static var _me: AiProfile


## Plays n duels; returns averaged stats.
static func run(enemy: EnemyDef, bot: String, n: int, opts: Dictionary) -> Dictionary:
	var wins := 0
	var turns := 0
	var in_range := 0
	var conf_left := 0
	var enemy_acts := 0
	var enemy_turns := 0
	var max_acts := 0
	var flow := [0, 0]
	var serves := {perfect = 0, all = 0}
	for s in range(1, n + 1):
		var o := opts.duplicate()
		o.seed = s
		var d := Duel.new(GameDB.deck("starter"), enemy, GameDB.book_recipes(["basics"]), o)
		var acts := {n = 0}
		d.card_played.connect(func(side: String, _c: CardInstance) -> void:
			if side == "enemy":
				acts.n += 1)
		d.dish_revealed.connect(func(side: String, recipe: RecipeDef, perfect: bool, _sig: bool, _b: bool) -> void:
			if side == "enemy":
				acts.n += 1
			elif recipe:
				serves.all += 1
				if perfect:
					serves.perfect += 1)
		var rng := SeededRng.new(s * 7919)
		var safety := 0
		while not d.over() and safety < 60:
			safety += 1
			if bot == "smart":
				_smart_turn(d)
			else:
				_simple_turn(d, rng)
			if d.over():
				break
			d.end_turn()
			var before: int = acts.n
			d.run_enemy_turn()
			enemy_turns += 1
			enemy_acts += acts.n - before
			max_acts = maxi(max_acts, acts.n - before)
		flow[0] += _mods(d.kitchen("player"))
		flow[1] += _mods(d.kitchen("enemy"))
		if d.phase == "won":
			wins += 1
			conf_left += d.player.confidence
		turns += d.turn
		if d.turn >= 5 and d.turn <= 8:
			in_range += 1
	return {
		win_pct = roundi(100.0 * wins / n),
		turns = float(turns) / n,
		in_range_pct = roundi(100.0 * in_range / n),
		conf_left = float(conf_left) / maxi(1, wins),
		acts_per_turn = float(enemy_acts) / maxi(1, enemy_turns),
		max_acts = max_acts,
		flow_player = float(flow[0]) / n,
		flow_enemy = float(flow[1]) / n,
		perfect_pct = roundi(100.0 * serves.perfect / maxi(1, serves.all)),
	}


static func _mods(k: Kitchen) -> int:
	var total := 0
	for v in k.modifiers.values():
		total += v
	return total


static func _smart_turn(d: Duel) -> void:
	if _me == null:
		_me = AiProfile.new()
		_me.w_attack = 1.0
		_me.w_defend = 0.6
		_me.w_patience = 0.3
		_me.w_debuff = 0.6
	for _i in RivalAI.MAX_STEPS:
		var a := RivalAI.choose(d, "player", _me)
		match a.kind:
			"place":
				d.play(a.uid, a.station)
			"technique":
				d.play(a.uid)
			"serve":
				d.serve(a.station)
				var offer := d.kitchen("player").offer
				if not offer.is_empty():
					d.pick_modifier(RivalAI.pick_modifier(d, offer, "player", _me).id)
		if a.kind == "end" or d.over():
			return


static func _simple_turn(d: Duel, rng: SeededRng) -> void:
	for _k in 10:
		var playable: Array[CardInstance] = []
		for c in d.hand:
			if d.can_play(c.uid).ok:
				playable.append(c)
		if playable.is_empty():
			break
		d.play(playable[rng.index(playable.size())].uid)
	for st in Duel.STATIONS:
		if d.can_serve(st).ok and (not d.recipe_check(st).ready.is_empty() or d.stack(st).size() >= 4):
			d.serve(st)
			var offer := d.kitchen("player").offer
			if not offer.is_empty():
				d.pick_modifier(offer[rng.index(offer.size())].id)
			break
