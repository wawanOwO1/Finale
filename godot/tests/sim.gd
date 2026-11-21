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
	d.plate = inst(["butter", "bread"]) # out of order (book: CARB -> FAT)
	var before := d.enemy.confidence
	check("toast serve ok", d.serve_as("toast").ok)
	check("toast out of order deals 6 + 2 Quality", lost(d, before) == 8, str(lost(d, before)))
	check("serve costs 1 Heat, Hype +25", d.player.heat == 2 and d.hype == 25)
	check("cannot serve twice per turn", not d.serve_as("").ok)
	check("toast draws 1", d.hand.size() == 1)

	d = new_duel(3)
	d.plate = inst(["egg", "egg", "bread"])
	before = d.enemy.confidence
	d.serve_as("")
	check("improvised deals 2 × 3", lost(d, before) == 6)
	check("serving a non-matching recipe is refused", not new_duel(3).serve_as("omelette").ok)

	d = new_duel(4)
	d.plate = inst(["egg"])
	d.player.composure = 4
	var conf := d.player.confidence
	d.end_turn() # Tony: Prepping 6
	check("plate kept across turns", d.plate.size() == 1)
	check("composure absorbs 4 of 6", conf - d.player.confidence == 2)
	check("composure reset on new turn", d.player.composure == 0 and d.turn == 2)


# ---------------------------------------------------------------- Perfect Order

func _perfect_order() -> void:
	check("omelette in book order (FAT, PROTEIN, VEGGIE)", RecipeMatch.in_order(GameDB.recipe("omelette"), inst(["butter", "egg", "tomato"])))
	check("omelette out of order", not RecipeMatch.in_order(GameDB.recipe("omelette"), inst(["egg", "butter", "tomato"])))
	check("extras between still count as in order", RecipeMatch.in_order(GameDB.recipe("omelette"), inst(["butter", "bread", "egg", "tomato"])))
	check("best_dish prefers the in-order recipe",
			RecipeMatch.best_dish(basics, inst(["bread", "butter", "tomato", "egg"])).id == "toast")
	check("best_dish prefers the bigger recipe when both in order",
			RecipeMatch.best_dish(basics, inst(["butter", "egg", "tomato", "bread"])).id == "omelette")

	var d := new_duel(20, dummy)
	d.plate = inst(["bread", "butter"])
	var before := d.enemy.confidence
	var seen := {perfect = false}
	d.dish_revealed.connect(func(_r, perfect, _s, _b): seen.perfect = perfect)
	d.serve()
	check("Perfect Order Toast: (6 + 2) x1.5 = 12", lost(d, before) == 12 and seen.perfect)

	d = new_duel(21, dummy)
	d.plate = inst(["egg", "egg"])
	var dish := {name = ""}
	d.dish_revealed.connect(func(r: RecipeDef, _p, _s, _b): dish.name = r.name if r else "Improvised")
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
	d.end_turn()
	check("Rattled counts down at the end of the rival turn", d.enemy.stacks("rattled") == 1)
	d.end_turn()
	check("Rattled expires after 2 rival turns", not d.enemy.statuses.has("rattled"))

	d = new_duel(6, GameDB.enemy("rosa"))
	var conf := d.player.confidence
	check("intent preview matches Rosa taunt (4)", d.pressure_from("enemy", d.intent().attack) == 4)
	d.end_turn() # Rosa: Taunt (4 Pressure, Flustered 2)
	check("Rosa taunt: 4 Pressure + Flustered 2", conf - d.player.confidence == 4 and d.player.stacks("flustered") == 2)
	h = give_hand(d, ["quickChop"])
	before = d.enemy.confidence
	d.play(h[0].uid)
	check("Flustered: 6 Pressure becomes 4", lost(d, before) == 4)
	d.end_turn()
	check("player Flustered counts down at end of own turn", d.player.stacks("flustered") == 1)

	d = new_duel(7, dummy)
	h = give_hand(d, ["chili"])
	d.play(h[0].uid)
	check("Chili: rival Spicy 2", d.enemy.stacks("spicy") == 2)
	before = d.enemy.confidence
	d.enemy.composure = 50 # Spicy ignores Composure
	d.end_turn()
	check("Spicy ticks 2 at rival turn start, ignores Composure", lost(d, before) == 2)
	check("Spicy then drops to 1", d.enemy.stacks("spicy") == 1)

	d = new_duel(8, dummy, 0, true)
	d.plate = inst(["egg", "chili"])
	d.serve_as("skewers")
	check("Skewers gives Focus 1", d.player.stacks("focus") == 1)
	h = give_hand(d, ["quickChop"])
	before = d.enemy.confidence
	d.play(h[0].uid)
	check("Focus: 6 Pressure becomes 7", lost(d, before) == 7)

	d = new_duel(9, dummy)
	d.player.statuses["burnt"] = 1
	d.plate = inst(["butter", "bread"])
	before = d.enemy.confidence
	d.serve_as("toast")
	check("Burnt halves the Serve: (6+2) / 2 = 4", lost(d, before) == 4)
	check("Burnt is used up", not d.player.statuses.has("burnt"))

	d = new_duel(10, dummy, 0, true)
	d.plate = inst(["bread", "tomato", "cheese"])
	d.serve_as("mushroomRisotto")
	check("Risotto gives Inspired 1", d.player.stacks("inspired") == 1)
	d.end_turn()
	check("Inspired: draw 6 next turn, then gone", d.hand.size() == 6 and not d.player.statuses.has("inspired"))

	d = new_duel(11, dummy)
	d.player.statuses["spicy"] = 3
	d.player.statuses["flustered"] = 2
	d.plate = inst(["tomato", "tomato"])
	d.serve_as("freshSalad")
	check("Fresh Salad removes 1 debuff (Spicy before Flustered)",
			not d.player.statuses.has("spicy") and d.player.stacks("flustered") == 2)


# ---------------------------------------------------------------- Signature Dish

func _signature() -> void:
	var d := new_duel(12, dummy)
	check("no Signature card below 100 Hype", not has_signature(d.hand))
	d.plate = inst(["butter", "bread"])
	d.hype = 75
	d.serve_as("toast")
	check("Hype 100 puts Signature Dish in hand", d.hype == 100 and has_signature(d.hand))
	d.end_turn()
	check("Signature Dish is retained over End Turn", has_signature(d.hand))

	var cut_in := {dish = ""}
	d.signature_served.connect(func(dish: String): cut_in.dish = dish)
	for c in d.hand:
		if c.def.special == "signature":
			d.play(c.uid)
			break
	check("playing it arms the next Serve", d.signature_armed and d.exhausted.size() == 1)
	d.plate = inst(["butter", "bread"])
	var before := d.enemy.confidence
	d.serve_as("toast")
	check("Signature Serve: (6+2) × 2 = 16", lost(d, before) == 16)
	check("cut-in event fires with the dish name", cut_in.dish == "Toast")
	check("Hype spent, not re-armed", d.hype == 0 and not d.signature_armed)
	d.end_turn()
	d.plate = inst(["bread", "butter"])
	d.hype = 99
	d.serve_as("toast")
	check("only once per duel", d.hype == 100 and not has_signature(d.hand))

	d = new_duel(13, dummy, 100)
	check("start Hype 100 hands out the Signature Dish", has_signature(d.hand))


# ---------------------------------------------------------------- random playthroughs

func _playthroughs(label: String, deck_id: String, enemy: EnemyDef, recipes: Array[RecipeDef]) -> void:
	var deck := GameDB.deck(deck_id)
	var n := 500
	var wins := 0
	var turns_total := 0
	var conserved := true
	var signatures := {count = 0}
	for s in range(1, n + 1):
		var d := Duel.new(deck, enemy, recipes, {seed = s})
		d.signature_served.connect(func(_dish): signatures.count += 1)
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
			if d.can_serve().ok and (not d.recipe_check().ready.is_empty() or d.plate.size() >= 4):
				d.serve()
			var total := d.draw_pile.size() + d.hand.size() + d.discard.size() + d.plate.size() + d.exhausted.size()
			if total != deck.size() + (1 if d.signature_given else 0):
				conserved = false
			if d.phase == "player":
				d.end_turn()
		if d.phase == "won":
			wins += 1
		turns_total += d.turn
	check("%s: cards conserved, every duel ends" % label, conserved)
	print("      random bot: %d/%d wins, avg %.1f turns, %d Signature Dishes" % [wins, n, float(turns_total) / n, signatures.count])
