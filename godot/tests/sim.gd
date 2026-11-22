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
	_playthroughs("starter vs Tony", "starter", GameDB.enemy("tony"), basics)
	_playthroughs("starter vs Rosa", "starter", GameDB.enemy("rosa"), basics)
	_playthroughs("dev deck vs Rosa", "dev", GameDB.enemy("rosa"), all_recipes)

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


func new_duel(seed_: int, enemy: EnemyDef = null, hype := 0, all := false) -> Duel:
	return Duel.new(GameDB.deck("starter"), enemy if enemy else GameDB.enemy("tony"),
			all_recipes if all else basics, {seed = seed_, hype = hype})


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

	d = new_duel(6, GameDB.enemy("rosa"))
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
	check("three empty stations", d.stations.size() == 3 and d.ingredient_count() == 0)
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
	check("empty station has an empty ticket", d.ticket(2).state == "empty")
	d.stations[2] = inst(["chili", "cheese"])
	check("off-path stack is Improvised", d.ticket(2).state == "improvised")
	d.stations[2] = inst(["butter", "bread"])
	check("toast out of order is Cooked", d.ticket(2).state == "cooked" and d.ticket(2).recipe.id == "toast")
	d.stations[2] = inst(["bread", "butter", "garlic"])
	check("toast in order + garnish is Perfect", d.ticket(2).state == "perfect" and d.ticket(2).garnish == 1)

	check("move top card", d.move_top(1, 2).ok and d.stack(1).size() == 1 and d.stack(2).back().def.id == "egg")
	check("only one move per turn", not d.move_top(2, 1).ok)
	check("clear also uses the move", not d.clear_station(0).ok)
	d.end_turn(); d.run_enemy_turn()
	var discard_before := d.discard.size()
	check("clear station after a new turn", d.clear_station(0).ok and d.stack(0).is_empty() and d.discard.size() == discard_before + 1)

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
	var d := new_duel(6, GameDB.enemy("rosa"))
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
