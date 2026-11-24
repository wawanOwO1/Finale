extends SceneTree
## Headless duel checks + random playthroughs (port of scripts/sim.ts). No rendering.
## Run:  godot --headless --path godot --script res://tests/sim.gd

var failures := 0
var uid_seq := 10000
var basics: Array[RecipeDef]
var all_recipes: Array[RecipeDef]
var dummy: EnemyDef


func _initialize() -> void:
	basics = GameDB.book_recipes(["basics"])
	all_recipes = GameDB.book_recipes(GameDB.ALL_BOOKS)
	# A rival that does nothing, so tests control exactly what happens.
	dummy = EnemyDef.new()
	dummy.id = "dummy"
	dummy.name = "Dummy"
	dummy.confidence = 200
	var idle := IntentDef.new()
	idle.label = "Idle"
	dummy.pattern = [idle]

	_recipe_matching()
	_core_loop()
	_perfect_order()
	_statuses()
	_signature()
	_stations()
	_rival_turn_steps()
	_symmetric_kitchen()
	_rival_ai()
	_rng()
	_chefs_flow()
	_almanac()
	_run_state()
	_playthroughs("starter vs Tony", "starter", GameDB.enemy("tony"), basics)
	_playthroughs("starter vs Rosa", "starter", GameDB.enemy("rosa"), basics)
	_playthroughs("dev deck vs Rosa", "dev", GameDB.enemy("rosa"), all_recipes)
	_smart_playthroughs("starter vs Tony", GameDB.enemy("tony"))
	_smart_playthroughs("starter vs Rosa", GameDB.enemy("rosa"))
	_balance()

	print("\n%d check(s) failed" % failures if failures else "\nAll checks passed")
	quit(1 if failures else 0)


# ---------------------------------------------------------------- helpers

func check(label: String, cond: bool, detail := "") -> void:
	if not cond:
		failures += 1
	print("%s  %s%s" % ["PASS" if cond else "FAIL", label, "  (%s)" % detail if not cond and detail else ""])


func inst(ids: Array) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for id in ids:
		out.append(CardInstance.new(uid_seq, GameDB.card(id)))
		uid_seq += 1
	return out


## `flow`: Chef's Flow thresholds. Out of reach by default so a Perfect Serve in an unrelated
## test never opens a pick; the Chef's Flow tests pin [2, 3, 4] (mechanics, not tuning).
func new_duel(seed_: int, enemy: EnemyDef = null, hype := 0, all := false, flow: PackedInt32Array = [99]) -> Duel:
	return Duel.new(GameDB.deck("starter"), enemy if enemy else intent_only("tony"),
			all_recipes if all else basics, {seed = seed_, hype = hype, player_flow = flow})


## A rival on its old intent pattern (no deck / AI), so tests control exactly what it does.
func intent_only(id: String) -> EnemyDef:
	var e: EnemyDef = GameDB.enemy(id).duplicate()
	e.deck = null
	e.ai = null
	return e

## Put exact cards in hand (and nothing else).
func give_hand(d: Duel, ids: Array) -> Array[CardInstance]:
	d.hand = inst(ids)
	return d.hand.duplicate()


func lost(d: Duel, before: int) -> int:
	return before - d.enemy.confidence


func has_signature(cards: Array[CardInstance]) -> bool:
	return cards.any(func(c: CardInstance) -> bool: return c.def.special == "signature")


# ---------------------------------------------------------------- recipe matching

func _recipe_matching() -> void:
	check("omelette matches egg+butter+tomato", RecipeMatch.missing_count(GameDB.recipe("omelette"), inst(["egg", "butter", "tomato"])) == 0)
	check("omelette with extras still matches", RecipeMatch.missing_count(GameDB.recipe("omelette"), inst(["egg", "butter", "tomato", "bread"])) == 0)
	check("omelette missing VEGGIE is 1 short", RecipeMatch.missing_count(GameDB.recipe("omelette"), inst(["egg", "butter"])) == 1)
	check("salad needs two distinct VEGGIE", RecipeMatch.missing_count(GameDB.recipe("freshSalad"), inst(["tomato"])) == 1)
	check("toast matches bread+butter", RecipeMatch.missing_count(GameDB.recipe("toast"), inst(["bread", "butter"])) == 0)
	check("steak needs Beef, not any PROTEIN", RecipeMatch.missing_count(GameDB.recipe("classicSteak"), inst(["chicken", "butter", "chili"])) == 1)
	check("steak with Beef matches", RecipeMatch.missing_count(GameDB.recipe("classicSteak"), inst(["beef", "butter", "chili"])) == 0)


# ---------------------------------------------------------------- core loop

func _core_loop() -> void:
	var d := new_duel(1)
	check("starts with 5 cards, 3 Heat, turn 1", d.hand.size() == 5 and d.player.heat == 3 and d.turn == 1)

	d = new_duel(2)
	d.hand = []
	d.stations[0] = inst(["butter", "bread"]) # out of order (book: CARB -> FAT)
	var before := d.enemy.confidence
	check("toast serve ok", d.serve_as("toast").ok)
	check("toast out of order deals 6 + 2 Quality", lost(d, before) == 8, str(lost(d, before)))
	check("serve costs 1 Heat, Hype +25", d.player.heat == 2 and d.hype == 25)
	check("cannot serve twice per turn", not d.serve_as("").ok)
	check("toast draws 1", d.hand.size() == 1)

	d = new_duel(3)
	d.stations[0] = inst(["egg", "egg", "bread"])
	before = d.enemy.confidence
	d.serve_as("")
	check("improvised deals 2 × 3", lost(d, before) == 6)
	check("serving a non-matching recipe is refused", not new_duel(3).serve_as("omelette").ok)

	d = new_duel(4)
	d.stations[0] = inst(["egg"])
	d.player.composure = 4
	var conf := d.player.confidence
	d.end_turn(); d.run_enemy_turn() # Tony: Prepping 6
	check("stations kept across turns", d.stack(0).size() == 1)
	check("composure absorbs 4 of 6", conf - d.player.confidence == 2)
	check("composure reset on new turn", d.player.composure == 0 and d.turn == 2)


# ---------------------------------------------------------------- Perfect Order

func _perfect_order() -> void:
	check("omelette in book order (FAT, PROTEIN, VEGGIE)", RecipeMatch.in_order(GameDB.recipe("omelette"), inst(["butter", "egg", "tomato"])))
	check("omelette out of order", not RecipeMatch.in_order(GameDB.recipe("omelette"), inst(["egg", "butter", "tomato"])))
	check("extras between the steps break Perfect", not RecipeMatch.in_order(GameDB.recipe("omelette"), inst(["butter", "bread", "egg", "tomato"])))
	check("garnish after the steps keeps Perfect", RecipeMatch.in_order(GameDB.recipe("omelette"), inst(["butter", "egg", "tomato", "garlic"])))
	check("best_dish prefers the in-order recipe",
			RecipeMatch.best_dish(basics, inst(["bread", "butter", "tomato", "egg"])).id == "toast")
	check("best_dish prefers the bigger recipe when both in order",
			RecipeMatch.best_dish(basics, inst(["butter", "egg", "tomato", "bread"])).id == "omelette")

	var d := new_duel(20, dummy)
	d.stations[0] = inst(["bread", "butter"])
	var before := d.enemy.confidence
	var seen := {perfect = false}
	d.dish_revealed.connect(func(_side, _r, perfect, _s, _b): seen.perfect = perfect)
	d.serve()
	check("Perfect Order Toast: (6 + 2) x1.5 = 12", lost(d, before) == 12 and seen.perfect)

	d = new_duel(21, dummy)
	d.stations[0] = inst(["egg", "egg"])
	var dish := {name = ""}
	d.dish_revealed.connect(func(_side, r: RecipeDef, _p, _s, _b): dish.name = r.name if r else "Improvised")
	d.serve()
	check("auto Serve with no recipe is Improvised", dish.name == "Improvised")


# ---------------------------------------------------------------- statuses

func _statuses() -> void:
	var d := new_duel(5, dummy)
	var h := give_hand(d, ["stareDown", "quickChop"])
	d.play(h[0].uid)
	check("Stare Down: rival Rattled 2", d.enemy.stacks("rattled") == 2)
	var before := d.enemy.confidence
	d.play(h[1].uid)
	check("Rattled: 6 Pressure becomes 9", lost(d, before) == 9)
	d.end_turn(); d.run_enemy_turn()
	check("Rattled counts down at the end of the rival turn", d.enemy.stacks("rattled") == 1)
	d.end_turn(); d.run_enemy_turn()
	check("Rattled expires after 2 rival turns", not d.enemy.statuses.has("rattled"))

	d = new_duel(6, intent_only("rosa"))
	var conf := d.player.confidence
	check("intent preview matches Rosa taunt (4)", d.pressure_from("enemy", d.intent().attack) == 4)
	d.end_turn(); d.run_enemy_turn() # Rosa: Taunt (4 Pressure, Flustered 2)
	check("Rosa taunt: 4 Pressure + Flustered 2", conf - d.player.confidence == 4 and d.player.stacks("flustered") == 2)
	h = give_hand(d, ["quickChop"])
	before = d.enemy.confidence
	d.play(h[0].uid)
	check("Flustered: 6 Pressure becomes 4", lost(d, before) == 4)
	d.end_turn(); d.run_enemy_turn()
	check("player Flustered counts down at end of own turn", d.player.stacks("flustered") == 1)

	d = new_duel(7, dummy)
	h = give_hand(d, ["chili"])
	d.play(h[0].uid)
	check("Chili: rival Spicy 2", d.enemy.stacks("spicy") == 2)
	before = d.enemy.confidence
	d.enemy.composure = 50 # Spicy ignores Composure
	d.end_turn(); d.run_enemy_turn()
	check("Spicy ticks 2 at rival turn start, ignores Composure", lost(d, before) == 2)
	check("Spicy then drops to 1", d.enemy.stacks("spicy") == 1)

	d = new_duel(8, dummy, 0, true)
	d.stations[0] = inst(["egg", "chili"])
	d.serve_as("skewers")
	check("Skewers gives Focus 1", d.player.stacks("focus") == 1)
	h = give_hand(d, ["quickChop"])
	before = d.enemy.confidence
	d.play(h[0].uid)
	check("Focus: 6 Pressure becomes 7", lost(d, before) == 7)

	d = new_duel(9, dummy)
	d.player.statuses["burnt"] = 1
	d.stations[0] = inst(["butter", "bread"])
	before = d.enemy.confidence
	d.serve_as("toast")
	check("Burnt halves the Serve: (6+2) / 2 = 4", lost(d, before) == 4)
	check("Burnt is used up", not d.player.statuses.has("burnt"))

	d = new_duel(10, dummy, 0, true)
	d.stations[0] = inst(["rice", "mushroom", "cheese"])
	d.serve_as("mushroomRisotto")
	check("Risotto gives Inspired 1", d.player.stacks("inspired") == 1)
	d.end_turn(); d.run_enemy_turn()
	check("Inspired: draw 6 next turn, then gone", d.hand.size() == 6 and not d.player.statuses.has("inspired"))

	d = new_duel(11, dummy)
	d.player.statuses["spicy"] = 3
	d.player.statuses["flustered"] = 2
	d.stations[0] = inst(["tomato", "tomato"])
	d.serve_as("freshSalad")
	check("Fresh Salad removes 1 debuff (Spicy before Flustered)",
			not d.player.statuses.has("spicy") and d.player.stacks("flustered") == 2)


# ---------------------------------------------------------------- Signature Dish

func _signature() -> void:
	var d := new_duel(12, dummy)
	check("no Signature card below 100 Hype", not has_signature(d.hand))
	d.stations[0] = inst(["butter", "bread"])
	d.hype = 75
	d.serve_as("toast")
	check("Hype 100 puts Signature Dish in hand", d.hype == 100 and has_signature(d.hand))
	d.end_turn(); d.run_enemy_turn()
	check("Signature Dish is retained over End Turn", has_signature(d.hand))

	var cut_in := {dish = ""}
	d.signature_served.connect(func(_side, dish: String): cut_in.dish = dish)
	for c in d.hand:
		if c.def.special == "signature":
			d.play(c.uid)
			break
	check("playing it arms the next Serve", d.signature_armed and d.exhausted.size() == 1)
	d.stations[0] = inst(["butter", "bread"])
	var before := d.enemy.confidence
	d.serve_as("toast")
	check("Signature Serve: (6+2) × 2 = 16", lost(d, before) == 16)
	check("cut-in event fires with the dish name", cut_in.dish == "Toast")
	check("Hype spent, not re-armed", d.hype == 0 and not d.signature_armed)
	d.end_turn(); d.run_enemy_turn()
	d.stations[0] = inst(["bread", "butter"])
	d.hype = 99
	d.serve_as("toast")
	check("only once per duel", d.hype == 100 and not has_signature(d.hand))

	d = new_duel(13, dummy, 100)
	check("start Hype 100 hands out the Signature Dish", has_signature(d.hand))


# ---------------------------------------------------------------- Station Stack

func _stations() -> void:
	var d := new_duel(30, dummy, 0, true)
	check("two empty stations", d.stations.size() == 2 and d.ingredient_count() == 0)
	var h := give_hand(d, ["butter", "egg", "bread"])
	d.play(h[0].uid, 1)
	check("ingredient goes to the chosen station", d.stack(1).size() == 1)
	d.play(h[1].uid)
	check("auto station continues a recipe path (butter -> egg)", d.stack(1).size() == 2)
	d.play(h[2].uid)
	check("auto station starts a new stack when off path", d.stack(0).size() == 1 and d.stack(0)[0].def.id == "bread")

	var tk := d.ticket(1)
	check("ticket while building: butter, egg -> a 3-step dish, step 3 is next",
			tk.state == "building" and tk.recipe.id in ["omelette", "mixedGrill"] and tk.steps[1].state == "done" and tk.steps[2].state == "next", str(tk.state))
	d.stations[0] = inst([])
	check("empty station has an empty ticket", d.ticket(0).state == "empty")
	d.stations[0] = inst(["chili", "cheese"])
	check("off-path stack is Improvised", d.ticket(0).state == "improvised")
	d.stations[0] = inst(["butter", "bread"])
	check("toast out of order is Cooked", d.ticket(0).state == "cooked" and d.ticket(0).recipe.id == "toast")
	d.stations[0] = inst(["bread", "butter", "garlic"])
	check("toast in order + garnish is Perfect", d.ticket(0).state == "perfect" and d.ticket(0).garnish == 1)

	check("move top card", d.move_top(1, 0).ok and d.stack(1).size() == 1 and d.stack(0).back().def.id == "egg")
	check("only one move per turn", not d.move_top(0, 1).ok)
	check("clear also uses the move", not d.clear_station(0).ok)
	d.end_turn(); d.run_enemy_turn()
	var discard_before := d.discard.size()
	var cleared := d.stack(0).size()
	check("clear station after a new turn", d.clear_station(0).ok and d.stack(0).is_empty() and d.discard.size() == discard_before + cleared)

	d = new_duel(31, dummy, 0, true)
	d.stations[1] = inst(["butter", "egg", "tomato"])
	var before := d.enemy.confidence
	check("serve a chosen station", d.serve(1).ok and d.stack(1).is_empty() and d.last_served_station == 1)
	check("Perfect Omelette: (10 + 3) x1.5 = 19", lost(d, before) == 19, str(lost(d, before)))
	check("serving an empty station is refused", not new_duel(32).serve(2).ok)

	d = new_duel(33, dummy)
	d.stations[0] = inst(["egg", "egg", "egg", "egg", "egg", "egg"])
	h = give_hand(d, ["tomato"])
	check("full station refuses a card", not d.can_play(h[0].uid, 0).ok and d.can_play(h[0].uid, 1).ok)

	d = new_duel(34, dummy, 0, true)
	d.stations[0] = inst(["bread", "beef", "cheese", "tomato", "bread"])
	before = d.enemy.confidence
	d.serve(0)
	var q := 0
	for id in ["bread", "beef", "cheese", "tomato", "bread"]:
		q += GameDB.card(id).quality
	check("Perfect Burger: (22 + Q) x1.5", lost(d, before) == floori((22 + q) * 1.5), str(lost(d, before)))


# ---------------------------------------------------------------- random playthroughs

## Rival turn runs one paced step at a time (GRAND_DESIGN §1.5).
func _rival_turn_steps() -> void:
	var d := new_duel(6, intent_only("rosa"))
	var conf := d.player.confidence
	var hand_card := d.hand[0].uid
	d.end_turn()
	check("end turn hands over to the rival", d.phase == "enemy")
	check("player cannot act on the rival turn", d.end_turn().reason == "Wait for your turn.")
	check("hand is discarded on end turn", d.hand.is_empty() and d.can_play(hand_card).reason == "Wait for your turn.")
	check("nothing hits before the first step", d.player.confidence == conf)
	var kinds: Array[String] = []
	while true:
		var a := d.enemy_step()
		kinds.append(a.kind)
		if a.kind == "attack":
			check("attack step lands alone (4, no Flustered yet)", conf - d.player.confidence == 4 and d.player.stacks("flustered") == 0)
		if a.kind == "end" or kinds.size() > 10:
			break
	check("Rosa taunt plays as attack, status, end", kinds == ["attack", "status", "end"], str(kinds))
	check("extra steps after end do nothing", d.enemy_step().kind == "end" and d.player.stacks("flustered") == 2)
	var t := d.turn
	d.start_player_turn()
	check("player turn starts after the rival ends", d.phase == "player" and d.turn == t + 1 and d.hand.size() == Duel.HAND_SIZE)
	check("rival pattern advanced once", d.intent().label != "Taunt" or d.enemy_def.pattern.size() == 1)


## The rival's Kitchen plays by the player's rules (GRAND_DESIGN §2).
func _symmetric_kitchen() -> void:
	var opts := {seed = 7, enemy_deck = GameDB.deck("starter"), enemy_recipes = basics}
	var d := Duel.new(GameDB.deck("starter"), dummy, basics, opts)
	var k := d.kitchen("enemy")
	check("rival deck is shuffled in, nothing drawn on Apis's turn", k.draw_pile.size() == 10 and k.hand.is_empty())
	k.hand = inst(["butter"])
	check("rival cannot act on Apis's turn", d.play(k.hand[0].uid, 0, "enemy").reason == "Wait for your turn.")
	k.hand.clear()

	d.end_turn()
	d.begin_enemy_turn()
	check("rival turn start: draws 5, Heat 3", k.hand.size() == Duel.HAND_SIZE and d.enemy.heat == Duel.MAX_HEAT)
	check("Apis cannot act on the rival turn", d.can_serve(0).reason == "Wait for your turn.")
	k.discard.append_array(k.hand)
	k.hand = inst(["butter", "egg", "tomato", "quickChop"])
	var player_stacks := d.ingredient_count("player")
	for i in 3:
		d.play(k.hand[0].uid, 0, "enemy")
	check("rival stacks on its own station", d.stack(0, "enemy").size() == 3 and d.ingredient_count("player") == player_stacks)
	check("rival ticket reads its own recipes", d.ticket(0, "enemy").get("recipe") != null)
	var conf := d.player.confidence
	d.play(k.hand[0].uid, -1, "enemy")
	check("rival technique hits Apis (Quick Chop 6)", conf - d.player.confidence == 6 and d.enemy.heat == 2)

	var seen := {}
	d.dish_served.connect(func(side, _r, pressure, _q, _n): seen.side = side; seen.pressure = pressure)
	conf = d.player.confidence
	var player_hype := d.hype
	check("rival serves", d.serve(0, "enemy").ok)
	check("rival Perfect Omelette hits Apis: (10 + 3) x1.5 = 19", conf - d.player.confidence == 19)
	check("dish_served says who cooked", seen.get("side") == "enemy" and seen.get("pressure") == 19)
	check("rival Omelette Composure goes to the rival", d.enemy.composure == 7)
	check("Hype goes to the rival's crowd only", k.hype == 25 and d.hype == player_hype)
	check("rival serves once per turn", d.serve(1, "enemy").reason == "Already served this turn.")
	d.run_enemy_turn()
	check("rival hand discarded at end of its turn", k.hand.is_empty() and d.phase == "player")
	check("rival cards conserved", k.card_total() == 10 + 4, str(k.card_total()))

	# Separate shuffle streams: the rival's shuffles never change Apis's draws.
	var a := Duel.new(GameDB.deck("starter"), dummy, basics, {seed = 11, enemy_deck = GameDB.deck("starter")})
	var b := Duel.new(GameDB.deck("starter"), dummy, basics, {seed = 11})
	for _t in 3:
		for x: Duel in [a, b]:
			x.end_turn()
			x.run_enemy_turn()
	check("Apis draws the same with or without a rival deck", _ids(a.hand) == _ids(b.hand), "%s vs %s" % [_ids(a.hand), _ids(b.hand)])


## Drafting rival (GRAND_DESIGN §3): legal, deterministic, fair, takes lethal, cooks in order.
func _rival_ai() -> void:
	var tony := GameDB.enemy("tony")
	check("Tony drafts with his own deck", tony.drafts())
	var d := Duel.new(GameDB.deck("starter"), tony, basics, {seed = 5})
	var k := d.kitchen("enemy")
	check("rival uses its def's Heat and hand size", k.max_heat == 2 and k.hand_size == 4)
	var conserved := true
	var kinds: Array[String] = []
	for _t in 4:
		d.end_turn()
		while d.phase == "enemy":
			var a := d.enemy_step()
			kinds.append(a.kind)
			if a.kind == "end" or a.kind == "none":
				break
		d.start_player_turn()
		if k.card_total() != 10:
			conserved = false
	check("rival plays cards over 4 turns", kinds.has("place") and kinds.has("serve"), str(kinds))
	check("rival hurts Apis", d.player.confidence < d.player.max_confidence)
	check("rival cards conserved every turn", conserved)

	# Same seed, same public info -> same rival turn (deterministic, no peeking at Apis's cards).
	var runs: Array = []
	for first in ["egg", "butter"]:
		var x := Duel.new(GameDB.deck("starter"), tony, basics, {seed = 9})
		x.stations[0] = inst([first])
		x.hand = inst(["chili", "beef"] if first == "egg" else ["tomato"])
		x.end_turn()
		var steps: Array[String] = []
		while x.phase == "enemy":
			var a := x.enemy_step()
			steps.append("%s:%s" % [a.kind, a.get("station", -1)])
			if a.kind == "end" or a.kind == "none":
				break
		runs.append(steps)
	check("rival ignores what Apis holds and which cards are on Apis's stations", runs[0] == runs[1], str(runs))

	# Lethal: a ready Perfect Omelette and Apis at 5 -> serve it first.
	d = Duel.new(GameDB.deck("starter"), GameDB.enemy("rosa"), basics, {seed = 3, confidence = 5})
	d.end_turn()
	d.begin_enemy_turn()
	d.kitchen("enemy").stations[0] = inst(["butter", "egg", "tomato"])
	check("mood: Confident with a big dish ready", RivalAI.mood(d) == "confident")
	var first := d.enemy_step()
	check("rival takes lethal right away", first.kind == "serve" and first.station == 0 and d.phase == "lost", str(first))

	# Cooks in book order: butter -> egg -> tomato = Perfect Omelette.
	var omelette_deck: Array[CardDef] = []
	for id in ["butter", "egg", "tomato", "egg"]:
		omelette_deck.append(GameDB.card(id))
	d = Duel.new(GameDB.deck("starter"), tony, basics, {seed = 4, enemy_deck = omelette_deck})
	d.end_turn()
	var served := {}
	while d.phase == "enemy":
		var a := d.enemy_step()
		if a.kind == "serve":
			served = a
		if a.kind == "end" or a.kind == "none":
			break
	check("rival builds and serves a Perfect Omelette", served.get("recipe") == GameDB.recipe("omelette") and served.get("perfect", false), str(served))

	# The Signature Dish stays Apis's move.
	d = Duel.new(GameDB.deck("starter"), tony, basics, {seed = 2})
	d.end_turn()
	d.begin_enemy_turn()
	d._add_hype(100, "enemy")
	check("a full rival crowd brings no Signature Dish", not has_signature(d.kitchen("enemy").hand) and d.kitchen("enemy").hype == 100)


func _ids(cards: Array[CardInstance]) -> Array[String]:
	var out: Array[String] = []
	for c in cards:
		out.append(c.def.id)
	return out


func _playthroughs(label: String, deck_id: String, enemy: EnemyDef, recipes: Array[RecipeDef]) -> void:
	var deck := GameDB.deck(deck_id)
	var n := 500
	var wins := 0
	var turns_total := 0
	var conserved := true
	var signatures := {count = 0}
	for s in range(1, n + 1):
		var d := Duel.new(deck, enemy, recipes, {seed = s})
		d.signature_served.connect(func(_side, _dish): signatures.count += 1)
		var pick_rng := SeededRng.new(s * 7919)
		var safety := 0
		while d.phase == "player" and safety < 100:
			safety += 1
			for _k in 10:
				var playable: Array[CardInstance] = []
				for c in d.hand:
					if d.can_play(c.uid).ok:
						playable.append(c)
				if playable.is_empty():
					break
				d.play(playable[floori(pick_rng.next() * playable.size())].uid)
			for st in Duel.STATIONS:
				if d.can_serve(st).ok and (not d.recipe_check(st).ready.is_empty() or d.stack(st).size() >= 4):
					d.serve(st)
					var offer := d.kitchen("player").offer
					if not offer.is_empty():
						d.pick_modifier(offer[pick_rng.index(offer.size())].id)
					break
			var total := d.draw_pile.size() + d.hand.size() + d.discard.size() + d.ingredient_count() + d.exhausted.size()
			if total != deck.size() + (1 if d.signature_given else 0):
				conserved = false
			if d.phase == "player":
				d.end_turn(); d.run_enemy_turn()
		if d.phase == "won":
			wins += 1
		turns_total += d.turn
	check("%s: cards conserved, every duel ends" % label, conserved)
	print("      random bot: %d/%d wins, avg %.1f turns, %d Signature Dishes" % [wins, n, float(turns_total) / n, signatures.count])


## Balancing (GRAND_DESIGN §8 G): RivalAI plays Apis's starter deck against each rival.
## Prints win rate, duel length and Confidence left; checks only that every duel ends.
func _smart_playthroughs(label: String, enemy: EnemyDef) -> void:
	var me := AiProfile.new()
	me.w_attack = 1.0
	me.w_defend = 0.6
	me.w_patience = 0.3
	me.w_debuff = 0.6
	var n := 300
	var wins := 0
	var turns_total := 0
	var conf_left := 0
	var ended := true
	var mods_taken := [0, 0]
	for s in range(1, n + 1):
		var d := Duel.new(GameDB.deck("starter"), enemy, basics, {seed = s})
		var safety := 0
		while not d.over() and safety < 60:
			safety += 1
			for _i in RivalAI.MAX_STEPS:
				var a := RivalAI.choose(d, "player", me)
				match a.kind:
					"place":
						d.play(a.uid, a.station)
					"technique":
						d.play(a.uid)
					"serve":
						d.serve(a.station)
						var offer := d.kitchen("player").offer
						if not offer.is_empty():
							d.pick_modifier(RivalAI.pick_modifier(d, offer, "player", me).id)
							mods_taken[0] += 1
				if a.kind == "end" or d.over():
					break
			if not d.over():
				d.end_turn()
				d.run_enemy_turn()
		mods_taken[1] += d.kitchen("enemy").modifiers.values().reduce(func(acc, v): return acc + v, 0)
		if not d.over():
			ended = false
		if d.phase == "won":
			wins += 1
			conf_left += d.player.confidence
		turns_total += d.turn
	check("smart Apis vs %s: every duel ends" % label.trim_prefix("starter vs "), ended)
	print("      smart bot %s: %d/%d wins, avg %.1f turns, avg Confidence left on a win %.0f/%d" % [
			label, wins, n, float(turns_total) / n, float(conf_left) / maxi(1, wins), Duel.PLAYER_CONFIDENCE])
	print("      Chef's Flow modifiers per duel: Apis %.2f, rival %.2f" % [float(mods_taken[0]) / n, float(mods_taken[1]) / n])


## Phase D (GRAND_DESIGN §4): independent streams, anti-clump shuffle, Mise en Place, AI ties.
func _rng() -> void:
	var a := SeededRng.stream(7, "offers")
	var b := SeededRng.stream(7, "offers")
	var c := SeededRng.stream(7, "ai_enemy")
	var same := true
	var differs := false
	for _i in 20:
		var x := a.next()
		same = same and is_equal_approx(x, b.next())
		differs = differs or not is_equal_approx(x, c.next())
	check("a named stream repeats from its seed", same)
	check("differently named streams differ", differs)

	# Anti-clump: a technique-heavy deck opens with 4+ Techniques on top far less often.
	var heavy: Array[CardDef] = []
	for id in ["quickChop", "quickChop", "quickChop", "stareDown", "stareDown", "quickChop", "egg", "bread", "butter", "tomato"]:
		heavy.append(GameDB.card(id))
	var raw := 0
	var shaped := 0
	for s in 400:
		var pile: Array[CardInstance] = []
		for def in heavy:
			pile.append(CardInstance.new(0, def))
		SeededRng.new(s).shuffle(pile)
		if Duel._clumped(pile):
			raw += 1
		var d := Duel.new(heavy, dummy, basics, {seed = s})
		if Duel._clumped(d.hand) and not d.kitchen("player").mise_used:
			shaped += 1
	check("anti-clump shuffle cuts Technique clumps", shaped * 4 < raw, "raw %d, shaped %d" % [raw, shaped])
	print("      opening clumps in 400 shuffles: raw %d, anti-clump %d" % [raw, shaped])

	# Mise en Place: a hand of only Techniques trades one for the top ingredient, once, visibly.
	var dry: Array[CardDef] = []
	for id in ["quickChop", "quickChop", "quickChop", "quickChop", "stareDown", "stareDown", "egg"]:
		dry.append(GameDB.card(id))
	var helped := 0
	var always_ingredient := true
	var conserved := true
	for s in 60:
		var d := Duel.new(dry, dummy, basics, {seed = s})
		var seen := [0]
		d.mise_en_place.connect(func(_side: String, _dr: CardInstance, _gb: CardInstance) -> void: seen[0] += 1)
		for _t in 3:
			if d.kitchen("player").mise_used:
				helped += 1
			var has_ing := false
			for card in d.hand:
				has_ing = has_ing or card.def.is_ingredient()
			always_ingredient = always_ingredient and has_ing
			conserved = conserved and d.kitchen("player").card_total() == 7
			d.end_turn()
			d.run_enemy_turn()
	check("Mise en Place always leaves an ingredient to place", always_ingredient)
	check("Mise en Place sometimes has to step in", helped > 0, str(helped))
	check("Mise en Place keeps every card", conserved)

	var rival := GameDB.enemy("tony").duplicate()
	rival.deck = DeckDef.new()
	rival.deck.cards.assign(dry)
	var rd := Duel.new(GameDB.deck("starter"), rival, basics, {seed = 4})
	var rival_mise := 0
	for _t in 4:
		rd.end_turn()
		rd.begin_enemy_turn()
		if rd.kitchen("enemy").mise_used:
			rival_mise += 1
		rd.run_enemy_turn()
	check("the rival gets the same Mise en Place", rival_mise > 0, str(rival_mise))

	# AI tie-breaks use their own stream: burning it changes nothing Apis draws.
	var hands: Array = []
	for burn in [0, 25]:
		var d := Duel.new(GameDB.deck("starter"), GameDB.enemy("tony"), basics, {seed = 11})
		for _i in burn:
			d.kitchen("enemy").ai_rng.next()
		d.end_turn()
		d.run_enemy_turn()
		var pile := _ids(d.hand)
		pile.append_array(_ids(d.draw_pile))
		hands.append(pile)
	check("AI tie-breaks never shift Apis's draws", hands[0] == hands[1], str(hands))

	# Equal options are spread out: the rival's first card does not always go to station 1.
	var stations := {}
	for s in 30:
		var d := Duel.new(GameDB.deck("starter"), GameDB.enemy("tony"), basics, {seed = s})
		d.end_turn()
		d.begin_enemy_turn()
		var step := d.enemy_step()
		if step.kind == "place":
			stations[step.station] = true
	check("tied placements vary between stations", stations.size() > 1, str(stations.keys()))


## A Perfect Order Toast on station 1, served; then the turn passes (dummy rival).
func _perfect_serve(d: Duel, next_turn := true) -> void:
	d.stations[0] = inst(["bread", "butter"])
	d.serve(0)
	if next_turn and d.kitchen("player").offer.is_empty():
		d.end_turn()
		d.run_enemy_turn()


## Phase E (GRAND_DESIGN §5): Chef's Flow meter, the 1-of-3 offer, and every modifier.
const FLOW: PackedInt32Array = [2, 3, 4]


func _chefs_flow() -> void:
	var d := new_duel(30, dummy, 0, false, FLOW)
	var k := d.kitchen("player")
	var offers := [0]
	d.flow_offer.connect(func(_side: String, _c: Array[ModifierDef]) -> void: offers[0] += 1)
	_perfect_serve(d)
	check("a Perfect Serve fills 1 Flow", k.flow == 1 and k.offer.is_empty())
	d.stations[0] = inst(["butter", "bread"])
	d.serve(0)
	check("a Cooked Serve adds no Flow", k.flow == 1)
	d.end_turn()
	d.run_enemy_turn()
	_perfect_serve(d)
	check("2 Perfect Serves offer 3 modifiers", k.offer.size() == 3 and offers[0] == 1, str(k.offer.size()))
	check("the meter resets and the next threshold is 3", k.flow == 0 and k.flow_threshold() == 3)
	check("no action until a pick", not d.end_turn().ok and d.end_turn().reason == Duel.PICK_FIRST)
	check("only an offered modifier can be picked", not d.pick_modifier("nope").ok)
	var first: ModifierDef = k.offer[0]
	check("picking takes it", d.pick_modifier(first.id).ok and k.mod(first.id) == 1 and k.offer.is_empty())
	check("play goes on after the pick", d.end_turn().ok)

	# Offer rules over many offers.
	var dupes := false
	var owned_again := false
	var longest_dry := 0
	var dry := 0
	var spice_offered := false
	for s in 40:
		var x := new_duel(100 + s, dummy, 0, false, FLOW)
		var xk := x.kitchen("player")
		for _i in 6:
			var o := x._make_offer("player")
			var ids := {}
			for m in o:
				dupes = dupes or ids.has(m.id)
				ids[m.id] = true
				owned_again = owned_again or (not m.stackable and xk.mod(m.id) > 0)
				spice_offered = spice_offered or m.id == "spice_whisperer"
			dry = 0 if o.any(func(m: ModifierDef) -> bool: return m.is_rare()) else dry + 1
			longest_dry = maxi(longest_dry, dry)
			xk.modifiers[o[0].id] = xk.mod(o[0].id) + 1
		dry = 0
	check("an offer never repeats a modifier", not dupes)
	check("a non-stackable modifier is never offered twice", not owned_again)
	check("rarity pity: never 4 offers in a row without a Rare", longest_dry <= Duel.RARE_PITY, str(longest_dry))
	check("Spice Whisperer stays out of a deck without SPICE", not spice_offered)
	var spicy_deck: Array[CardDef] = []
	for id in ["chili", "chili", "chili", "bread", "butter", "egg", "tomato"]:
		spicy_deck.append(GameDB.card(id))
	var always := true
	for s in 30:
		var x := Duel.new(spicy_deck, dummy, basics, {seed = s})
		always = always and x._make_offer("player").any(func(m: ModifierDef) -> bool: return m.id == "spice_whisperer")
	check("a SPICE deck is always offered its build modifier", always)

	# Each modifier, applied directly.
	d = new_duel(31, dummy, 0, false, FLOW)
	d.kitchen("player").modifiers = {hot_pan = 1}
	var before := d.enemy.confidence
	_perfect_serve(d, false)
	check("Hot Pan: Perfect Toast 12 + 3", lost(d, before) == 15, str(lost(d, before)))
	d = new_duel(31, dummy, 0, false, FLOW)
	d.kitchen("player").modifiers = {encore = 1}
	before = d.enemy.confidence
	_perfect_serve(d, false)
	check("Encore: (6 + 2) x1.75 = 14", lost(d, before) == 14, str(lost(d, before)))
	d = new_duel(31, dummy, 0, false, FLOW)
	d.kitchen("player").modifiers = {plating_pro = 1}
	d.stations[0] = inst(["bread", "butter", "tomato"])
	before = d.enemy.confidence
	d.serve(0)
	check("Plating Pro: garnish counts twice, (6 + 4) x1.5 = 15", lost(d, before) == 15, str(lost(d, before)))
	d = new_duel(31, dummy, 0, false, FLOW)
	d.kitchen("player").modifiers = {crowd_favorite = 1}
	var hype_before := d.hype
	_perfect_serve(d, false)
	check("Crowd Favorite: +10 Hype on top", d.hype == hype_before + GameDB.recipe("toast").hype + 10)
	d = new_duel(31, dummy, 0, false, FLOW)
	d.kitchen("player").modifiers = {extra_burner = 1, prep_cook = 1}
	_perfect_serve(d)
	check("Extra Burner: +1 Heat after a Perfect Serve", d.player.heat == Duel.MAX_HEAT + 1, str(d.player.heat))
	check("Prep Cook: draws 1 more", d.hand.size() == Duel.HAND_SIZE + 1, str(d.hand.size()))
	d = new_duel(31, dummy, 0, false, FLOW)
	d.kitchen("player").modifiers = {steady_hands = 1, spice_whisperer = 1}
	var chili := give_hand(d, ["chili"])[0]
	d.play(chili.uid, 1)
	check("Steady Hands: +1 Composure per ingredient", d.player.composure >= 1)
	check("Spice Whisperer: SPICE gives the rival Spicy", d.enemy.stacks("spicy") >= 1)
	d = new_duel(31, dummy, 0, false, FLOW)
	d.kitchen("player").modifiers = {free_move = 1}
	d.stations[0] = inst(["bread", "butter", "egg"])
	check("Free Move: 2 moves a turn", d.move_top(0, 1).ok and d.move_top(0, 1).ok and not d.move_top(0, 1).ok)
	var mm := 0
	var plain := 0
	var two_tech: Array[CardDef] = []
	for id in ["quickChop", "quickChop", "quickChop", "stareDown", "egg", "bread", "butter", "tomato"]:
		two_tech.append(GameDB.card(id))
	for s in 60:
		var x := Duel.new(two_tech, dummy, basics, {seed = s})
		x.kitchen("player").modifiers = {mise_master = 1}
		x.end_turn()
		x.run_enemy_turn()
		var ing := x.hand.filter(func(c: CardInstance) -> bool: return c.def.is_ingredient()).size()
		if x.kitchen("player").mise_used and ing >= 2:
			mm += 1
		if ing < 2:
			plain += 1
	check("Mise Master: steps in on a 1-ingredient hand", mm > 0 and plain == 0, "%d helped, %d left short" % [mm, plain])

	# The rival takes its own pick, and its step reports it.
	var tony := GameDB.enemy("tony")
	var r := Duel.new(GameDB.deck("starter"), tony, basics, {seed = 6})
	var rk := r.kitchen("enemy")
	check("rival thresholds come from its EnemyDef", rk.flow_threshold() == tony.flow_thresholds[0])
	rk.flow = rk.flow_threshold() - 1
	rk.stations[0] = inst(["bread", "butter"])
	var gained := {}
	r.modifier_gained.connect(func(side: String, m: ModifierDef, _n: int) -> void: gained[side] = m.id)
	r.end_turn()
	var reported := ""
	while r.phase == "enemy":
		var a := r.enemy_step()
		if a.has("modifier"):
			reported = a.modifier.id
		if a.kind == "end" or a.kind == "none":
			break
	check("the rival picks a modifier on its own", gained.has("enemy") and rk.offer.is_empty() and not rk.modifiers.is_empty())
	check("the rival's Serve step names the modifier", reported != "" and reported == gained.get("enemy", ""), reported)
	check("Flow is per duel", Duel.new(GameDB.deck("starter"), tony, basics, {seed = 6}).kitchen("enemy").modifiers.is_empty())


# ---------------------------------------------------------------- Almanac (GRAND_DESIGN §6)

func _almanac() -> void:
	print("\n-- Almanac")
	var a := Almanac.new()
	var fresh: Array[String] = []
	a.discovered.connect(func(kind: String, id: String) -> void: fresh.append("%s:%s" % [kind, id]))
	a.prepare(GameDB.deck("starter"), basics)
	check("your deck's cards are discovered", a.knows_card("bread") and a.knows_card("quickChop"))
	check("cards you never had stay hidden", not a.knows_card("chili"))
	check("mastered books' recipes are discovered", a.knows_recipe("toast") and a.recipe_source("toast") == Almanac.MASTERED)
	check("other books' recipes stay hidden", not a.knows_recipe("hotWings"))
	check("each discovery is announced once", fresh.count("card:bread") == 1 and fresh.has("recipe:toast"))
	check("new entries carry the NEW badge", a.is_new("recipe", "toast"))
	a.mark_seen("recipe", "toast")
	check("looking at an entry clears NEW", not a.is_new("recipe", "toast"))

	# A duel: the rival is met at once, its dishes are "Seen from", its gimmick after the end.
	var d := Duel.new(GameDB.deck("starter"), GameDB.enemy("tony"), basics, {seed = 77})
	a.watch(d)
	check("rival is met when the duel starts", a.knows_rival("tony") and not a.rival_finished("tony"))
	d.dish_served.emit("enemy", GameDB.recipe("hotWings"), 8, 2, 3)
	check("a dish the rival serves is seen from them", a.recipe_source("hotWings") == "tony")
	check("the rival's served list records it", a.served_by("tony") == PackedStringArray(["hotWings"]))
	d.dish_served.emit("enemy", GameDB.recipe("toast"), 5, 1, 2)
	check("a mastered recipe stays mastered when the rival serves it", a.recipe_source("toast") == Almanac.MASTERED)
	d.dish_served.emit("player", GameDB.recipe("omelette"), 5, 1, 2)
	check("your own Serves do not log the rival", a.served_by("tony").size() == 2)
	a.discover_recipe("hotWings", Almanac.MASTERED)
	check("mastering a seen recipe upgrades it", a.recipe_source("hotWings") == Almanac.MASTERED)
	d._lose_confidence("enemy", 999, "pressure")
	check("gimmick opens once the duel ended", a.rival_finished("tony"))

	# Save / load round trip.
	var path := "user://almanac_sim_test.save"
	check("almanac saves", a.save(path))
	var b := Almanac.load_from(path)
	check("load keeps cards, recipes and sources", b.cards == a.cards and b.recipes == a.recipes)
	check("load keeps rivals and their dishes", b.rival_finished("tony") and b.served_by("tony") == a.served_by("tony"))
	check("load keeps NEW badges", b.unseen.keys().size() == a.unseen.keys().size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check("a missing save gives an empty almanac", Almanac.load_from(path).count() == 0)

	# Combination finder (§6.3).
	var toast := GameDB.recipe("toast")
	var burger := GameDB.recipe("burger")
	check("a tag pick fits its slot", Almanac.cover(toast, ["FAT"]) == ([false, true] as Array[bool]))
	check("an ingredient pick fills a slot of its tag", Almanac.pick_fits("card:butter", "FAT"))
	check("a tag pick fills a key ingredient of that tag", Almanac.pick_fits("PROTEIN", "card:beef"))
	check("two picks need two slots", Almanac.cover(toast, ["FAT", "FAT"]).is_empty())
	var two_breads := Almanac.cover(burger, ["card:bread", "card:bread"])
	check("two breads cover both bun slots", two_breads == ([true, false, false, false, true] as Array[bool]))
	var hits := Almanac.find(all_recipes, ["SPICE"])
	var names := hits.map(func(h: Dictionary) -> String: return h.recipe.id)
	check("finder lists recipes using a tag", names.has("hotWings") and not names.has("toast"), str(names))
	check("finder rejects recipes missing a pick", Almanac.find([toast], ["DAIRY"]).is_empty())
	var uses := Almanac.uses_of(GameDB.card("butter"), all_recipes).map(func(r: RecipeDef) -> String: return r.id)
	check("Used in lists the recipes an ingredient fits", uses.has("toast"), str(uses))


# ---------------------------------------------------------------- RunState (GDD §6)

func _run_state() -> void:
	print("\n-- RunState")
	var r := RunState.start()
	check("a new run starts with the starter deck", r.deck.size() == GameDB.deck("starter").size() and r.deck.size() > 0)
	check("a new run starts at full Confidence (100)", r.confidence == 100 and r.max_confidence == 100)
	check("a new run has no Tips, Tools or wins", r.tips == 0 and r.tools.is_empty() and r.duels_won == 0 and not r.over)
	check("a new run masters only the Basics Cookbook", r.books == PackedStringArray(["basics"]) and r.recipes().size() == basics.size())

	# The duel is built from the run: Confidence in, extras merged on top.
	var d := r.new_duel(dummy, {seed = 5, hype = 0, player_flow = [99]})
	check("the duel starts with the run's deck", d.draw_pile.size() + d.hand.size() == r.deck.size())
	check("the duel uses the run's recipes", d.recipes.size() == r.recipes().size())
	r.confidence = 64
	var d2 := r.new_duel(dummy, {seed = 5, player_flow = [99]})
	check("the duel starts at the run's Confidence", d2.player.confidence == 64 and d2.player.max_confidence == 100)
	check("extra options override the run's", r.duel_opts({confidence = 10}).confidence == 10)
	var deck_before := r.deck.size()
	d2.draw_pile.clear()
	check("a duel never changes the run's deck", r.deck.size() == deck_before)

	# Settling a duel: a win carries Confidence, a loss ends the run, an unfinished duel changes nothing.
	r.finish_duel(d2)
	check("an unfinished duel settles nothing", r.confidence == 64 and r.duels_won == 0 and not r.over)
	d2.player.confidence = 41
	d2.phase = "won"
	r.finish_duel(d2)
	check("a win carries the Confidence you have left", r.confidence == 41 and r.duels_won == 1)
	r.finish_duel(d2)
	check("settling the same duel twice counts once", r.duels_won == 1)
	var d3 := r.new_duel(dummy, {seed = 6, player_flow = [99]})
	check("the next duel starts from the carried Confidence", d3.player.confidence == 41)
	d3.player.confidence = 0
	d3.phase = "won"
	r.finish_duel(d3)
	check("a win never leaves Confidence at 0", r.confidence == 1)
	var d4 := r.new_duel(dummy, {seed = 7, player_flow = [99]})
	d4.phase = "lost"
	r.finish_duel(d4)
	check("a loss ends the run", r.over and r.duels_won == 2)

	# Confidence: heal clamps to the cap, reports what it gave.
	var h := RunState.start()
	h.confidence = 70
	check("heal restores Confidence and reports it", h.heal(20) == 20 and h.confidence == 90)
	check("heal stops at the maximum", h.heal(50) == 10 and h.confidence == 100)
	h.change_max_confidence(10)
	check("a higher cap raises Confidence too", h.max_confidence == 110 and h.confidence == 110)
	h.change_max_confidence(-30)
	check("a lower cap pulls Confidence down to it", h.max_confidence == 80 and h.confidence == 80)

	# Tips.
	var t := RunState.start()
	t.add_tips(120)
	check("Tips add up", t.tips == 120 and t.can_afford(120) and not t.can_afford(121))
	check("spending Tips pays the price", t.spend_tips(75) and t.tips == 45)
	check("you cannot spend Tips you do not have", not t.spend_tips(46) and t.tips == 45)
	t.add_tips(-10)
	check("negative Tips are ignored", t.tips == 45)

	# Deck.
	var butter := GameDB.card("butter")
	var n := t.count_card(butter)
	t.add_card(butter)
	check("a card is added to the deck", t.count_card(butter) == n + 1)
	check("removal takes one copy", t.remove_card(butter) and t.count_card(butter) == n)
	var chili := GameDB.card("chili")
	check("removing a card you do not have fails", t.count_card(chili) == 0 and not t.remove_card(chili))

	# Books and Tools.
	check("a new book is mastered", t.add_book("grill") and t.has_book("grill"))
	check("a mastered book adds its recipes", t.recipes().size() == GameDB.book_recipes(["basics", "grill"]).size())
	check("a book is never mastered twice", not t.add_book("grill") and t.books.size() == 2)
	check("an unknown book is refused", not t.add_book("nope") and t.books.size() == 2)
	check("a Kitchen Tool is gained once", t.add_tool("grandmasPan") and t.has_tool("grandmasPan") and not t.add_tool("grandmasPan") and t.tools.size() == 1)


# ---------------------------------------------------------------- balance targets (phase G)

## Guards the tuning from GRAND_DESIGN §8.1 / §8.2 so a content change that breaks it shows up.
## Ranges are loose on purpose; tests/balance.gd prints the full picture.
func _balance() -> void:
	print("\n-- Balance targets (tests/balance.gd for details)")
	var Bots := preload("res://tests/balance_runner.gd")
	var n := 200
	var tony_simple: Dictionary = Bots.run(GameDB.enemy("tony"), "simple", n, {})
	var tony_smart: Dictionary = Bots.run(GameDB.enemy("tony"), "smart", n, {})
	var rosa_simple: Dictionary = Bots.run(GameDB.enemy("rosa"), "simple", n, {})
	var rosa_smart: Dictionary = Bots.run(GameDB.enemy("rosa"), "smart", n, {})
	check("Tony loses about 80%% to a simple player (65-90): %d%%" % tony_simple.win_pct,
			tony_simple.win_pct >= 65 and tony_simple.win_pct <= 90)
	check("Tony rarely beats a careful player (>= 90): %d%%" % tony_smart.win_pct, tony_smart.win_pct >= 90)
	check("Rosa is harder than Tony for both players",
			rosa_simple.win_pct < tony_simple.win_pct and rosa_smart.win_pct < tony_smart.win_pct)
	check("a careful player still beats Rosa mostly (70-95): %d%%" % rosa_smart.win_pct,
			rosa_smart.win_pct >= 70 and rosa_smart.win_pct <= 95)
	for pair in [["Tony simple", tony_simple], ["Tony smart", tony_smart], ["Rosa simple", rosa_simple], ["Rosa smart", rosa_smart]]:
		var s: Dictionary = pair[1]
		check("%s: duel lasts 4.5-8.5 turns on average: %.1f" % [pair[0], s.turns], s.turns >= 4.5 and s.turns <= 8.5)
		check("%s: rival averages <= 6 actions a turn (§9): %.1f" % [pair[0], s.acts_per_turn], s.acts_per_turn <= 6.0)
	check("Chef's Flow: a careful player gets ~1 modifier a duel (>= 0.7): %.2f / %.2f" % [
			tony_smart.flow_player, rosa_smart.flow_player], tony_smart.flow_player >= 0.7 and rosa_smart.flow_player >= 0.7)
