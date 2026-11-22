class_name Duel
extends RefCounted
## Duel state machine (GDD §4). Pure logic: no nodes, no rendering.
## The UI calls play / serve / end_turn and redraws on `changed`; visuals (stage, VFX, audio)
## listen to the other signals. The logic never depends on who listens (GDD §9).
##
## Symmetric (GRAND_DESIGN §2): each side has a Kitchen (hand, deck, stations, Hype, Heat) and
## every action takes a `side` ("player" | "enemy", default "player"). A side may only act on
## its own turn (phase == side). The player-only fields below (hand, stations, hype, …) are
## shortcuts to the player's Kitchen so the HUD and tests read them as before.

signal turn_started(turn: int)
## side: "player" | "enemy" (who acted) in every signal below that has it.
signal card_played(side: String, card: CardInstance)
## `recipe` is null for an Improvised Dish. `pressure` = what the Serve took off the other side.
signal dish_served(side: String, recipe: RecipeDef, pressure: int, quality: int, count: int)
## target: "player" | "enemy"
signal pressure_dealt(target: String, amount: int, blocked: int)
## source: "pressure" | "spicy"
signal confidence_lost(target: String, amount: int, source: String)
signal composure_gained(target: String, amount: int)
signal enemy_acted(intent: IntentDef)
signal status_applied(target: String, status: String, amount: int)
signal signature_ready(side: String)
signal signature_served(side: String, dish: String)
## Emitted before the effects so the dish reveal plays ahead of the damage numbers.
signal dish_revealed(side: String, recipe: RecipeDef, perfect: bool, signature: bool, burnt: bool)
## winner: "player" | "enemy"
signal duel_ended(winner: String)
## Mise en Place (GRAND_DESIGN §4.2): a hand with nothing to place traded `given_back` (a
## Technique, back into the draw pile) for `drawn` (the top ingredient of the draw pile).
signal mise_en_place(side: String, drawn: CardInstance, given_back: CardInstance)
## Chef's Flow (GRAND_DESIGN §5): a Perfect Serve filled the meter. The player picks with
## pick_modifier(); the rival picks on its own (then modifier_gained follows at once).
signal flow_offer(side: String, choices: Array[ModifierDef])
signal modifier_gained(side: String, modifier: ModifierDef, stacks: int)
signal changed

const MAX_HEAT := 3
const HAND_SIZE := 5
## Station Stack (ART_DIRECTION §6): three columns, each stacks up to 6 ingredients in order.
const STATIONS := 3
const STATION_SIZE := 6
const SERVE_COST := 1
const MAX_HYPE := 100
## Station starts with the recipe's steps in Recipe Book order (Perfect). Any other order = Cooked ×1.
const PERFECT_ORDER_MULT := 1.5
## Salt for the rival's shuffle stream, derived from the duel seed.
const ENEMY_RNG_SALT := 0x5bd1e995
## Anti-clump shuffle (GRAND_DESIGN §4.2): this many Techniques among the top CLUMP_WINDOW
## cards of a fresh shuffle counts as a clump and is reshuffled, at most CLUMP_RETRIES times.
const CLUMP_TECHNIQUES := 4
const CLUMP_WINDOW := 5
const CLUMP_RETRIES := 3
## Chef's Flow thresholds for Apis (rivals set theirs in EnemyDef.flow_thresholds).
const PLAYER_FLOW: PackedInt32Array = [2, 3, 4]
## Offer slot 3 is Rare this often (GRAND_DESIGN §5.2); 3 offers without one guarantee it.
const RARE_CHANCE := 0.25
const RARE_PITY := 3
const PICK_FIRST := "Pick a modifier first."

## Signature Dish (GDD §4.5): appears in hand when Hype is full, once per duel.
static var SIGNATURE_CARD: CardDef = _make_signature_card()


class Fighter:
	var confidence: int
	var max_confidence: int
	var composure := 0
	var heat := 0
	## status id -> stacks (> 0). Missing key = no status.
	var statuses := {}

	func _init(confidence_: int, max_confidence_: int) -> void:
		confidence = confidence_
		max_confidence = max_confidence_

	func stacks(id: String) -> int:
		return statuses.get(id, 0)


var player: Fighter
var enemy: Fighter
var enemy_def: EnemyDef
## side -> Kitchen
var kitchens := {}

## The duel's seed. Every RNG stream (shuffles, AI tie-breaks, later the modifier offers) is
## derived from it, so one seed reproduces the whole duel (GRAND_DESIGN §4.3).
var duel_seed := 0
var turn := 0
## "player" | "enemy" | "won" | "lost"
var phase := "player"
## Newest last; the HUD shows the tail.
var log_lines: PackedStringArray = []

# ---- Player Kitchen shortcuts (HUD, tests). Use kitchen("enemy") for the rival's.
var recipes: Array[RecipeDef]:
	get: return kitchens.player.recipes
	set(v): kitchens.player.recipes = v
var draw_pile: Array[CardInstance]:
	get: return kitchens.player.draw_pile
	set(v): kitchens.player.draw_pile = v
var hand: Array[CardInstance]:
	get: return kitchens.player.hand
	set(v): kitchens.player.hand = v
var discard: Array[CardInstance]:
	get: return kitchens.player.discard
	set(v): kitchens.player.discard = v
var exhausted: Array[CardInstance]:
	get: return kitchens.player.exhausted
var stations: Array:
	get: return kitchens.player.stations
var last_served_station: int:
	get: return kitchens.player.last_served_station
var hype: int:
	get: return kitchens.player.hype
	set(v): kitchens.player.hype = v
var served_this_turn: bool:
	get: return kitchens.player.served_this_turn
var moved_this_turn: bool:
	get: return kitchens.player.moved_this_turn
var signature_given: bool:
	get: return kitchens.player.signature_given
var signature_armed: bool:
	get: return kitchens.player.signature_armed

var _intent_index := 0
## Rival turn: actions still to play this turn, and whether its start / end already ran.
var _enemy_queue: Array[Dictionary] = []
var _enemy_started := false
var _enemy_ended := false
## Drafting rival: the decided-but-not-played next action (RivalAI.choose), and steps this turn.
var _ai_next := {}
var _ai_steps := 0
var _next_uid := 0


## opts: { confidence, max_confidence, hype, seed, enemy_deck: Array[CardDef],
##         enemy_recipes: Array[RecipeDef] } — all optional. A drafting rival (EnemyDef with a
## deck and an AI profile) brings its own deck, books, Heat and hand size; enemy_deck /
## enemy_recipes override them (tests).
func _init(deck: Array[CardDef], enemy_def_: EnemyDef, recipes_: Array[RecipeDef], opts := {}) -> void:
	var rng_seed: int = opts.get("seed", int(Time.get_unix_time_from_system() * 1000.0))
	var max_conf: int = opts.get("max_confidence", 60)
	player = Fighter.new(opts.get("confidence", max_conf), max_conf)
	enemy_def = enemy_def_
	enemy = Fighter.new(enemy_def.confidence, enemy_def.confidence)
	duel_seed = rng_seed
	kitchens.player = Kitchen.new("player", player, SeededRng.new(rng_seed))
	kitchens.enemy = Kitchen.new("enemy", enemy, SeededRng.new(rng_seed ^ ENEMY_RNG_SALT))
	kitchens.player.ai_rng = SeededRng.stream(rng_seed, "ai_player")
	kitchens.enemy.ai_rng = SeededRng.stream(rng_seed, "ai_enemy")
	kitchens.player.offer_rng = SeededRng.stream(rng_seed, "offers")
	kitchens.enemy.offer_rng = SeededRng.stream(rng_seed, "offers_enemy")
	kitchens.player.flow_thresholds = PLAYER_FLOW
	if not enemy_def.flow_thresholds.is_empty():
		kitchens.enemy.flow_thresholds = enemy_def.flow_thresholds
	kitchens.player.recipes = recipes_
	var enemy_recipes: Array[RecipeDef] = []
	var enemy_deck: Array[CardDef] = []
	if enemy_def.drafts():
		enemy_recipes = GameDB.book_recipes(enemy_def.books)
		enemy_deck.assign(enemy_def.deck.cards)
		kitchens.enemy.max_heat = enemy_def.max_heat
		kitchens.enemy.hand_size = enemy_def.hand_size
	if opts.has("enemy_recipes"):
		enemy_recipes.assign(opts.enemy_recipes)
	if opts.has("enemy_deck"):
		enemy_deck.assign(opts.enemy_deck)
	kitchens.enemy.recipes = enemy_recipes
	_fill_deck("player", deck)
	_fill_deck("enemy", enemy_deck)
	_start_turn("player")
	# Starting Hype goes through _add_hype so a full meter hands out the Signature Dish.
	if opts.get("hype", 0) > 0:
		_add_hype(opts.hype, "player")


# ---------------------------------------------------------------- queries

func kitchen(side: String) -> Kitchen:
	return kitchens[side]


func fighter(side: String) -> Fighter:
	return player if side == "player" else enemy


func chef_name(side: String) -> String:
	return "Apis" if side == "player" else enemy_def.name


## The rival's next intent (old pattern AI). null for a drafting rival or an empty pattern.
func intent() -> IntentDef:
	var p := enemy_def.pattern
	if drafting() or p.is_empty():
		return null
	return p[_intent_index % p.size()]


## The rival drafts with its own Kitchen (GRAND_DESIGN §3) instead of the intent pattern.
func drafting() -> bool:
	return enemy_def.drafts()


## { ready: Array[RecipeDef], almost: Array[RecipeDef] } for one station.
func recipe_check(station := 0, side := "player") -> Dictionary:
	return RecipeMatch.check(kitchen(side).recipes, stack(station, side))


func stack(station: int, side := "player") -> Array[CardInstance]:
	return kitchen(side).stack(station)


## Order Ticket for one station (see RecipeMatch.ticket).
func ticket(station: int, side := "player") -> Dictionary:
	return RecipeMatch.ticket(kitchen(side).recipes, stack(station, side))


func ingredient_count(side := "player") -> int:
	return kitchen(side).ingredient_count()


## Where an ingredient goes when no station is given: a station whose recipe path it continues,
## else an empty station, else any station with room. -1 = all full.
func auto_station(card: CardInstance, side := "player") -> int:
	var k := kitchen(side)
	for i in STATIONS:
		var st := k.stack(i)
		if not st.is_empty() and st.size() < STATION_SIZE and RecipeMatch.accepts_next(k.recipes, st, card):
			return i
	for i in STATIONS:
		if k.stack(i).is_empty():
			return i
	for i in STATIONS:
		if k.stack(i).size() < STATION_SIZE:
			return i
	return -1


## Pressure after statuses: (base + attacker Focus) × 0.75 if attacker Flustered
## × 1.5 if defender Rattled, rounded down. Used for attacks and intent previews.
func pressure_from(attacker: String, base: int) -> int:
	var a := fighter(attacker)
	var d := fighter(_other(attacker))
	var v := float(base + a.stacks("focus"))
	if a.stacks("flustered") > 0:
		v *= 0.75
	if d.stacks("rattled") > 0:
		v *= 1.5
	return maxi(0, floori(v))


func over() -> bool:
	return phase == "won" or phase == "lost"


## Kind of the rival's next step ("place", "serve", "attack", … or "end"), without playing it.
func enemy_next_kind() -> String:
	if phase != "enemy" or _enemy_ended:
		return "end"
	if drafting():
		return _peek_ai().kind
	return _enemy_queue[0].kind if not _enemy_queue.is_empty() else "end"


## Rival steps still queued this turn (0 = the next enemy_step ends the turn).
func enemy_actions_left() -> int:
	if phase != "enemy" or _enemy_ended:
		return 0
	if drafting():
		return 0 if _peek_ai().kind == "end" else 1
	return _enemy_queue.size()


# ---------------------------------------------------------------- checks

## { ok: bool, reason: String }
## station: target for an ingredient (-1 = auto_station). Ignored for techniques.
func can_play(uid: int, station := -1, side := "player") -> Dictionary:
	if phase != side:
		return _not_your_turn()
	if not kitchen(side).offer.is_empty():
		return _fail(PICK_FIRST)
	var k := kitchen(side)
	var i := k.hand_index(uid)
	if i < 0:
		return _fail("Card is not in hand.")
	var card := k.hand[i]
	if card.def.cost > k.fighter.heat:
		return _fail("Not enough Heat.")
	if card.def.is_ingredient():
		var s := station if station >= 0 else auto_station(card, side)
		if s < 0 or s >= STATIONS or k.stack(s).size() >= STATION_SIZE:
			return _fail("That station is full." if station >= 0 else "Every station is full.")
	return _ok()


func can_serve(station := 0, side := "player") -> Dictionary:
	if phase != side:
		return _not_your_turn()
	if not kitchen(side).offer.is_empty():
		return _fail(PICK_FIRST)
	var k := kitchen(side)
	if k.served_this_turn:
		return _fail("Already served this turn.")
	if station < 0 or station >= STATIONS or k.stack(station).is_empty():
		return _fail("That station is empty.")
	if k.fighter.heat < SERVE_COST:
		return _fail("Not enough Heat.")
	return _ok()


## Move the top (newest) card of one station onto another. Once per turn, free.
func can_move(from: int, to: int, side := "player") -> Dictionary:
	if phase != side:
		return _not_your_turn()
	if not kitchen(side).offer.is_empty():
		return _fail(PICK_FIRST)
	var k := kitchen(side)
	if not _move_left(k):
		return _fail("Already moved a card this turn.")
	if from == to or from < 0 or to < 0 or from >= STATIONS or to >= STATIONS:
		return _fail("Pick another station.")
	if k.stack(from).is_empty():
		return _fail("That station is empty.")
	if k.stack(to).size() >= STATION_SIZE:
		return _fail("That station is full.")
	return _ok()


# ---------------------------------------------------------------- actions

func move_top(from: int, to: int, side := "player") -> Dictionary:
	var result := can_move(from, to, side)
	if not result.ok:
		return result
	var k := kitchen(side)
	var card: CardInstance = k.stack(from).pop_back()
	k.stack(to).append(card)
	_use_move(k)
	_say("%s moves to station %d." % [card.def.name, to + 1])
	changed.emit()
	return _ok()


## Throw a whole station into the discard pile. Free, but uses the turn's move.
func clear_station(station: int, side := "player") -> Dictionary:
	if phase != side:
		return _not_your_turn()
	if not kitchen(side).offer.is_empty():
		return _fail(PICK_FIRST)
	var k := kitchen(side)
	if not _move_left(k):
		return _fail("Already moved a card this turn.")
	if station < 0 or station >= STATIONS or k.stack(station).is_empty():
		return _fail("That station is empty.")
	k.discard.append_array(k.stack(station))
	k.stack(station).clear()
	_use_move(k)
	_say("Station %d cleared." % (station + 1))
	changed.emit()
	return _ok()


func play(uid: int, station := -1, side := "player") -> Dictionary:
	var result := can_play(uid, station, side)
	if not result.ok:
		return result
	var k := kitchen(side)
	var card: CardInstance = k.hand.pop_at(k.hand_index(uid))
	k.fighter.heat -= card.def.cost

	if card.def.is_ingredient():
		var s := station if station >= 0 else auto_station(card, side)
		k.stack(s).append(card)
		_say("%s goes on station %d." % [card.def.name, s + 1])
	else:
		(k.exhausted if card.def.exhaust else k.discard).append(card)
		_say("%s uses %s." % [chef_name(side), card.def.name])
	if card.def.special == "signature":
		k.signature_armed = true
		_say("Signature Dish ready! Next Serve ×2.")
	card_played.emit(side, card)
	_apply_effects(card.def.effects, 0, 1.0, side)
	if card.def.is_ingredient() and not over():
		if mods(side, "steady_hands") > 0:
			_gain_composure(side, int(GameDB.modifier("steady_hands").amount) * mods(side, "steady_hands"))
		if mods(side, "spice_whisperer") > 0 and card.def.tags.has("SPICE"):
			_add_status(_other(side), "spicy", int(GameDB.modifier("spice_whisperer").amount) * mods(side, "spice_whisperer"))
	changed.emit()
	return _ok()


## Serve one whole station. The game cooks the best matching dish (RecipeMatch.best_dish),
## the one its Order Ticket shows. Tests use serve_as() to force one.
func serve(station := 0, side := "player") -> Dictionary:
	var result := can_serve(station, side)
	if not result.ok:
		return result
	return _do_serve(RecipeMatch.best_dish(kitchen(side).recipes, stack(station, side)), station, side)


## Force a recipe by id, or "" for an Improvised Dish (tests / debug).
func serve_as(recipe_id: String, station := 0, side := "player") -> Dictionary:
	var result := can_serve(station, side)
	if not result.ok:
		return result
	var recipe: RecipeDef = null
	if recipe_id != "":
		for r: RecipeDef in recipe_check(station, side).ready:
			if r.id == recipe_id:
				recipe = r
		if recipe == null:
			return _fail("That recipe does not match the station.")
	return _do_serve(recipe, station, side)


# ---------------------------------------------------------------- turn flow (public)

## Ends the player's turn and hands it to the rival (phase "enemy"). The rival then acts one
## step at a time so the UI can pace it (GRAND_DESIGN §1):
##   end_turn() → begin_enemy_turn() → enemy_step() until kind "end" → start_player_turn()
## Tests and sims without animation call run_enemy_turn() for the whole rival turn.
func end_turn() -> Dictionary:
	if phase != "player":
		return _not_your_turn()
	if not kitchens.player.offer.is_empty():
		return _fail(PICK_FIRST)
	_end_turn_cleanup("player")
	phase = "enemy"
	_enemy_started = false
	_enemy_ended = false
	changed.emit()
	return _ok()


## Start of the rival's turn: the same start as Apis's (Composure fades, Spicy ticks, Heat,
## draw). A pattern rival then queues its intent's actions; a drafting rival decides one
## action at a time in enemy_step.
func begin_enemy_turn() -> void:
	if phase != "enemy" or _enemy_started:
		return
	_enemy_started = true
	_enemy_queue.clear()
	_ai_next = {}
	_ai_steps = 0
	_start_turn("enemy")
	if over():
		return
	var it := intent()
	if it:
		_say("%s: %s!" % [enemy_def.name, it.label])
		if it.has_attack():
			_enemy_queue.append({kind = "attack", base = it.attack})
		if it.block > 0:
			_enemy_queue.append({kind = "block", amount = it.block})
		if it.has_status():
			var side := "player" if it.status_target == IntentDef.StatusTarget.PLAYER else "enemy"
			_enemy_queue.append({kind = "status", status = it.status, amount = it.status_amount, target = side})
	changed.emit()


## Applies the rival's next action and returns it. "end" also closes the rival's turn (hand
## discarded, end-of-turn decay). "none" = not the rival's turn (or the duel ended mid-turn).
##   Pattern rival:  { kind: "attack", amount } | { kind: "block", amount } | { kind: "status", … }
##   Drafting rival: { kind: "place", station, card } | { kind: "technique", card }
##                   | { kind: "serve", station, recipe, perfect }
## `card` is for the visuals' timing only: the HUD never shows the rival's cards (GRAND_DESIGN §3.5).
func enemy_step() -> Dictionary:
	if phase != "enemy":
		return {kind = "none"}
	begin_enemy_turn()
	if over():
		return {kind = "none"}
	if _enemy_ended:
		return {kind = "end"}
	if drafting():
		var next := _peek_ai()
		_ai_next = {}
		if next.kind != "end":
			_ai_steps += 1
			var done := _apply_ai(next)
			if not done.is_empty():
				changed.emit()
				return done
	if _enemy_queue.is_empty():
		_enemy_ended = true
		var it := intent()
		if it:
			enemy_acted.emit(it)
		_intent_index += 1
		_end_turn_cleanup("enemy")
		changed.emit()
		return {kind = "end"}
	var a: Dictionary = _enemy_queue.pop_front()
	match a.kind:
		"attack":
			a.amount = pressure_from("enemy", a.base)
			_deal_pressure("player", a.amount)
		"block":
			_gain_composure("enemy", a.amount)
		"status":
			_add_status(a.target, a.status, a.amount)
	changed.emit()
	return a


## Rival turn is over (enemy_step returned "end"): Apis's turn starts (Composure, Spicy, draw).
func start_player_turn() -> void:
	if phase != "enemy":
		return
	phase = "player"
	_start_turn("player")
	changed.emit()


## The whole rival turn at once, for tests/sims (no pacing).
func run_enemy_turn() -> void:
	while phase == "enemy":
		if enemy_step().kind == "end":
			break
	start_player_turn()


# ---------------------------------------------------------------- serve

func _do_serve(recipe: RecipeDef, station: int, side: String) -> Dictionary:
	var k := kitchen(side)
	var target := fighter(_other(side))
	var served: Array[CardInstance] = k.stack(station).duplicate()
	var perfect := recipe != null and RecipeMatch.in_order(recipe, served)

	k.fighter.heat -= SERVE_COST
	k.served_this_turn = true
	k.last_served_station = station
	k.stack(station).clear()
	var quality := dish_quality(recipe, served, side)
	var target_before := target.confidence + target.composure

	# Effect multiplier: Perfect Order ×1.5, Signature Dish ×2, Burnt ×0.5 (all stack).
	var mult := perfect_mult(side) if perfect else 1.0
	var signature := k.signature_armed
	if signature:
		mult *= 2.0
		k.signature_armed = false
	var burnt := k.fighter.stacks("burnt") > 0
	if burnt:
		mult *= 0.5
		_add_status(side, "burnt", -1)
		_say("Burnt! This Serve is halved.")

	var dish_name := recipe.name if recipe else "Improvised Dish"
	if signature:
		signature_served.emit(side, dish_name)
	dish_revealed.emit(side, recipe, perfect, signature, burnt)

	if recipe:
		_say("SERVE! %s (+%d Quality)%s%s" % [recipe.name, quality,
				" Perfect Order!" if perfect else "", " ×2" if signature else ""])
		# Recipe effect = base value + total Plate Quality (GDD §4.4), on the headline effect.
		_apply_effects(recipe.effects, quality, mult, side)
	else:
		_say("Improvised Dish: %d ingredients.%s" % [served.size(), " ×2" if signature else ""])
		_apply_effects([EffectDef.make(EffectDef.Kind.PRESSURE, 2 * served.size())], 0, mult, side)
	# The Signature Dish spends the crowd; otherwise a recipe Serve builds Hype.
	if signature:
		k.hype = 0
	elif recipe:
		_add_hype(recipe.hype, side)
	# Modifiers (GRAND_DESIGN §5.3): Hot Pan hits harder, Crowd Favorite builds Hype.
	if serve_bonus(side) > 0 and not over():
		_deal_pressure(_other(side), pressure_from(side, serve_bonus(side)))
	if mods(side, "crowd_favorite") > 0:
		_add_hype(int(GameDB.modifier("crowd_favorite").amount) * mods(side, "crowd_favorite"), side)
	if perfect and mods(side, "extra_burner") > 0:
		k.burner_next = true

	k.discard.append_array(served)
	var dealt := target_before - (target.confidence + target.composure)
	dish_served.emit(side, recipe, dealt, quality, served.size())
	# Chef's Flow: a Perfect Order Serve fills the meter (after the dish, so its reveal comes first).
	if perfect and not over():
		_gain_flow(side)
	changed.emit()
	return _ok()


# ---------------------------------------------------------------- turn flow (rules)

## Start of a side's turn (GDD §4.2 step 1): Composure → 0, Spicy ticks, Heat refills, draw.
func _start_turn(side: String) -> void:
	var k := kitchen(side)
	if side == "player":
		turn += 1
	k.fighter.composure = 0
	k.served_this_turn = false
	k.moved_this_turn = false
	k.extra_moves = 0
	_tick_spicy(side)
	if over():
		return
	k.fighter.heat = k.max_heat
	if k.burner_next:
		k.burner_next = false
		k.fighter.heat += int(GameDB.modifier("extra_burner").amount)
	var inspired := k.fighter.stacks("inspired")
	if inspired > 0:
		_add_status(side, "inspired", -inspired)
	_draw(k.hand_size + inspired + mods(side, "prep_cook"), side)
	k.mise_used = false
	_mise_en_place(side)
	if side == "player":
		turn_started.emit(turn)


## End of a side's turn (GDD §4.2 step 4): hand discarded except Retain cards, stations stay,
## Flustered and Rattled count down.
func _end_turn_cleanup(side: String) -> void:
	var k := kitchen(side)
	var kept: Array[CardInstance] = []
	for c in k.hand:
		(kept if c.def.retain else k.discard).append(c)
	k.hand = kept
	for id in ["flustered", "rattled"]:
		if k.fighter.stacks(id) > 0:
			_add_status(side, id, -1)


## Spicy: lose X Confidence (ignores Composure), then X − 1.
func _tick_spicy(side: String) -> void:
	var x := fighter(side).stacks("spicy")
	if x <= 0:
		return
	_say("%s feels the burn: −%d" % [chef_name(side), x])
	_lose_confidence(side, x, "spicy")
	_add_status(side, "spicy", -1)


# ---------------------------------------------------------------- effects

## Effects of a card or dish played by `side`. `bonus` is added to the first effect's amount
## (recipe Quality); `mult` scales it all.
func _apply_effects(effects: Array[EffectDef], bonus: int, mult: float, side: String) -> void:
	for i in effects.size():
		if over():
			return
		var e := effects[i]
		var scaled := floori((e.amount + (bonus if i == 0 else 0)) * mult)
		match e.kind:
			EffectDef.Kind.PRESSURE:
				_deal_pressure(_other(side), pressure_from(side, scaled))
			EffectDef.Kind.COMPOSURE:
				_gain_composure(side, scaled)
			EffectDef.Kind.HEAL:
				_heal(scaled, side)
			EffectDef.Kind.DRAW:
				_draw(e.amount, side)
			EffectDef.Kind.HYPE:
				_add_hype(e.amount, side)
			EffectDef.Kind.STATUS:
				var to := side if e.target == EffectDef.Target.SELF else _other(side)
				_add_status(to, e.status, maxi(1, scaled))
			EffectDef.Kind.CLEANSE:
				_cleanse(e.amount, side)


## Pressure hits Composure first, then Confidence. `amount` already includes statuses.
func _deal_pressure(target: String, amount: int) -> void:
	var f := fighter(target)
	var blocked := mini(f.composure, amount)
	f.composure -= blocked
	pressure_dealt.emit(target, amount, blocked)
	_lose_confidence(target, amount - blocked, "pressure")


func _lose_confidence(target: String, amount: int, source: String) -> void:
	var f := fighter(target)
	if amount > 0:
		confidence_lost.emit(target, mini(amount, f.confidence), source)
	f.confidence = maxi(0, f.confidence - amount)
	if f.confidence == 0 and not over():
		phase = "won" if target == "enemy" else "lost"
		_say("%s gives up!" % enemy_def.name if target == "enemy" else "Apis loses heart...")
		duel_ended.emit(_other(target))


func _add_status(side: String, id: String, delta: int) -> void:
	var s := fighter(side).statuses
	var v: int = s.get(id, 0) + delta
	if v > 0:
		s[id] = v
	else:
		s.erase(id)
	if delta > 0:
		status_applied.emit(side, id, delta)


func _cleanse(count: int, side: String) -> void:
	var f := fighter(side)
	for _n in count:
		var found := ""
		for id in StatusDefs.CLEANSE_ORDER:
			if f.stacks(id) > 0:
				found = id
				break
		if found == "":
			return
		f.statuses.erase(found)
		_say("Cleansed %s." % found)


func _gain_composure(target: String, amount: int) -> void:
	fighter(target).composure += amount
	composure_gained.emit(target, amount)


func _heal(amount: int, side: String) -> void:
	var f := fighter(side)
	f.confidence = mini(f.max_confidence, f.confidence + amount)


func _add_hype(amount: int, side: String) -> void:
	var k := kitchen(side)
	k.hype = mini(MAX_HYPE, k.hype + amount)
	# The Signature Dish is the MC's move (GDD §4.5): a rival's full crowd brings no card.
	if side == "player" and k.hype >= MAX_HYPE and not k.signature_given:
		k.signature_given = true
		k.hand.append(_instance(SIGNATURE_CARD))
		_say("The crowd goes wild! Signature Dish unlocked!")
		signature_ready.emit(side)


func _draw(n: int, side: String) -> void:
	var k := kitchen(side)
	for _i in n:
		if k.draw_pile.is_empty():
			if k.discard.is_empty():
				return
			k.draw_pile = k.discard
			k.discard = []
			_shuffle(k)
		k.hand.append(k.draw_pile.pop_back())


## Fisher–Yates, then reshuffle a Technique clump on top (the draw end) a few times before
## accepting it. Light pseudo-random: it removes the worst streaks, not the luck.
func _shuffle(k: Kitchen) -> void:
	for _try in CLUMP_RETRIES + 1:
		k.rng.shuffle(k.draw_pile)
		if not _clumped(k.draw_pile):
			return


static func _clumped(pile: Array[CardInstance]) -> bool:
	var n := 0
	for i in mini(CLUMP_WINDOW, pile.size()):
		if not pile[pile.size() - 1 - i].def.is_ingredient():
			n += 1
	return n >= CLUMP_TECHNIQUES


## Bad-luck protection after the start-of-turn draw: a hand with no ingredient that can be
## placed swaps one Technique for the top ingredient of the draw pile. Once per turn, for both
## sides, and announced, so it is never hidden help.
func _mise_en_place(side: String) -> void:
	var k := kitchen(side)
	if k.mise_used:
		return
	# Mise Master: also when the hand holds just 1 placeable ingredient.
	var allowed := 1 if mods(side, "mise_master") > 0 else 0
	var placeable := 0
	var technique: CardInstance = null
	for c in k.hand:
		if c.def.is_ingredient() and _placeable(c, k):
			placeable += 1
			if placeable > allowed:
				return
		if technique == null and not c.def.is_ingredient() and c.def.special != "signature":
			technique = c
	if technique == null:
		return
	for i in range(k.draw_pile.size() - 1, -1, -1):
		var c := k.draw_pile[i]
		if c.def.is_ingredient() and _placeable(c, k):
			k.draw_pile[i] = technique
			k.hand[k.hand.find(technique)] = c
			k.mise_used = true
			_say("Mise en place! %s preps %s." % [chef_name(side), c.def.name])
			mise_en_place.emit(side, c, technique)
			return


## An ingredient this kitchen could put down this turn (affordable, a station has room).
static func _placeable(c: CardInstance, k: Kitchen) -> bool:
	if c.def.cost > k.fighter.heat:
		return false
	for s in STATIONS:
		if k.stack(s).size() < STATION_SIZE:
			return true
	return false


# ---------------------------------------------------------------- helpers

## The drafting rival's next action, decided once and kept until it is played.
func _peek_ai() -> Dictionary:
	if _ai_next.is_empty():
		_ai_next = {kind = "end"} if _ai_steps >= RivalAI.MAX_STEPS else RivalAI.choose(self)
	return _ai_next


## Plays a RivalAI action with the normal rules. Returns the step for the visuals, or {} when
## the action was refused (then the rival ends its turn instead of looping).
func _apply_ai(a: Dictionary) -> Dictionary:
	var k := kitchen("enemy")
	match a.kind:
		"place", "technique":
			var i := k.hand_index(a.uid)
			if i < 0:
				return {}
			var card := k.hand[i]
			var station: int = a.get("station", -1)
			if not play(a.uid, station, "enemy").ok:
				return {}
			return {kind = a.kind, station = station, card = card}
		"serve":
			var recipe := RecipeMatch.best_dish(k.recipes, k.stack(a.station))
			var perfect := recipe != null and RecipeMatch.in_order(recipe, k.stack(a.station))
			k.gained = null
			if not serve(a.station, "enemy").ok:
				return {}
			var step := {kind = "serve", station = a.station, recipe = recipe, perfect = perfect}
			# Chef's Flow modifier the rival took with this Serve (the Turn Director announces it).
			if k.gained:
				step.modifier = k.gained
				k.gained = null
			return step
	return {}


func _fill_deck(side: String, deck: Array[CardDef]) -> void:
	var k := kitchen(side)
	for def in deck:
		k.draw_pile.append(_instance(def))
	_shuffle(k)


func _instance(def: CardDef) -> CardInstance:
	var c := CardInstance.new(_next_uid, def)
	_next_uid += 1
	return c


func _say(line: String) -> void:
	log_lines.append(line)
	if log_lines.size() > 30:
		log_lines.remove_at(0)


static func _other(side: String) -> String:
	return "enemy" if side == "player" else "player"


static func _ok() -> Dictionary:
	return {ok = true, reason = ""}


static func _fail(reason: String) -> Dictionary:
	return {ok = false, reason = reason}


func _not_your_turn() -> Dictionary:
	return _fail("The duel is over." if over() else "Wait for your turn.")


static func _make_signature_card() -> CardDef:
	var c := CardDef.new()
	c.id = "signature"
	c.name = "Signature Dish"
	c.type = CardDef.Type.TECHNIQUE
	c.cost = 0
	c.text = "Your next Serve has ×2 effect. Retain. Once per duel."
	c.retain = true
	c.exhaust = true
	c.special = "signature"
	return c


# ---------------------------------------------------------------- Chef's Flow (GRAND_DESIGN §5)

## Stacks of a modifier on `side` (0 = not owned).
func mods(side: String, id: String) -> int:
	return kitchen(side).mod(id)


## The Perfect Order multiplier for `side` (Encore raises it).
func perfect_mult(side: String) -> float:
	var enc := GameDB.modifier("encore")
	return PERFECT_ORDER_MULT + enc.amount * mods(side, "encore")


## Quality a dish gets from `plate` (Plating Pro multiplies the Garnish part).
func dish_quality(recipe: RecipeDef, plate: Array[CardInstance], side: String) -> int:
	var q := RecipeMatch.plate_quality(plate)
	if recipe and mods(side, "plating_pro") > 0:
		var extra := int(GameDB.modifier("plating_pro").amount) - 1
		for i in range(recipe.requires.size(), plate.size()):
			q += plate[i].def.quality * extra
	return q


## Flat Pressure a Serve adds on top of the dish (Hot Pan).
func serve_bonus(side: String) -> int:
	return int(GameDB.modifier("hot_pan").amount) * mods(side, "hot_pan")


## The player picks one of the offered modifiers (the pick-1-of-3 overlay).
func pick_modifier(id: String, side := "player") -> Dictionary:
	var k := kitchen(side)
	for m in k.offer:
		if m.id == id:
			_take_modifier(side, m)
			changed.emit()
			return _ok()
	return _fail("That modifier is not on offer.")


func _gain_flow(side: String) -> void:
	var k := kitchen(side)
	k.flow += 1
	if k.flow < k.flow_threshold():
		return
	k.flow = 0
	k.flow_level += 1
	var choices := _make_offer(side)
	if choices.is_empty():
		return
	_say("Chef's Flow! %s is on a roll." % chef_name(side))
	if side == "player":
		k.offer = choices
		flow_offer.emit(side, choices)
	else:
		flow_offer.emit(side, choices)
		_take_modifier(side, RivalAI.pick_modifier(self, choices, side))


func _take_modifier(side: String, m: ModifierDef) -> void:
	var k := kitchen(side)
	k.offer = []
	k.modifiers[m.id] = k.mod(m.id) + 1
	k.gained = m
	_say("%s takes %s." % [chef_name(side), m.name])
	modifier_gained.emit(side, m, k.mod(m.id))


## 2 Commons + 1 slot (Rare 25%, or for sure after RARE_PITY offers without one), never a
## non-stackable modifier already owned, and one that fits the deck's build when there is one.
func _make_offer(side: String) -> Array[ModifierDef]:
	var k := kitchen(side)
	var build := build_tags(side)
	var commons: Array[ModifierDef] = []
	var rares: Array[ModifierDef] = []
	for m in GameDB.modifiers():
		if not m.stackable and k.mod(m.id) > 0:
			continue
		# Never offer a modifier made for a tag this deck does not use.
		if m.tag != "" and not build.has(m.tag):
			continue
		(rares if m.is_rare() else commons).append(m)
	var out: Array[ModifierDef] = []
	for _i in 2:
		_take_random(commons, out, k.offer_rng)
	var rare := k.offers_without_rare >= RARE_PITY or k.offer_rng.next() < RARE_CHANCE
	if rare and not rares.is_empty():
		_take_random(rares, out, k.offer_rng)
	else:
		_take_random(commons, out, k.offer_rng)
	# Pool running dry: fill from whatever is left.
	while out.size() < 3 and not (commons.is_empty() and rares.is_empty()):
		_take_random(commons if not commons.is_empty() else rares, out, k.offer_rng)
	# Build match: a modifier made for a tag the deck leans on takes the first Common slot.
	if not out.any(func(m: ModifierDef) -> bool: return m.tag != ""):
		var pool := commons.filter(func(m: ModifierDef) -> bool: return m.tag != "")
		if not pool.is_empty() and not out.is_empty():
			out[0] = pool[k.offer_rng.index(pool.size())]
	var has_rare := out.any(func(m: ModifierDef) -> bool: return m.is_rare())
	k.offers_without_rare = 0 if has_rare else k.offers_without_rare + 1
	return out


static func _take_random(from: Array[ModifierDef], into: Array[ModifierDef], rng: SeededRng) -> void:
	if from.is_empty():
		return
	into.append(from.pop_at(rng.index(from.size())))


## Ingredient tags with 3+ cards in this side's deck (its "build").
func build_tags(side: String) -> Dictionary:
	var k := kitchen(side)
	var count := {}
	var piles: Array = [k.draw_pile, k.hand, k.discard, k.exhausted]
	piles.append_array(k.stations)
	for pile: Array in piles:
		for c: CardInstance in pile:
			if c.def.is_ingredient():
				for t in c.def.tags:
					count[t] = count.get(t, 0) + 1
	var out := {}
	for t in count:
		if count[t] >= 3:
			out[t] = true
	return out


func _move_left(k: Kitchen) -> bool:
	if not k.moved_this_turn:
		return true
	var fm := k.mod("free_move")
	return fm > 0 and 1 + k.extra_moves < int(GameDB.modifier("free_move").amount)


func _use_move(k: Kitchen) -> void:
	if k.moved_this_turn:
		k.extra_moves += 1
	k.moved_this_turn = true
