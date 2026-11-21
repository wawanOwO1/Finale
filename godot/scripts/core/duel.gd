class_name Duel
extends RefCounted
## Duel state machine (GDD §4). Pure logic: no nodes, no rendering.
## The UI calls play / serve / end_turn and redraws on `changed`; visuals (stage, VFX, audio)
## listen to the other signals. The logic never depends on who listens (GDD §9).

signal turn_started(turn: int)
signal card_played(card: CardInstance)
## `recipe` is null for an Improvised Dish.
signal dish_served(recipe: RecipeDef, pressure: int, quality: int, count: int)
## target: "player" | "enemy"
signal pressure_dealt(target: String, amount: int, blocked: int)
## source: "pressure" | "spicy"
signal confidence_lost(target: String, amount: int, source: String)
signal composure_gained(target: String, amount: int)
signal enemy_acted(intent: IntentDef)
signal status_applied(target: String, status: String, amount: int)
signal signature_ready
signal signature_served(dish: String)
## Emitted before the effects so the dish reveal plays ahead of the damage numbers.
signal dish_revealed(recipe: RecipeDef, perfect: bool, signature: bool, burnt: bool)
## winner: "player" | "enemy"
signal duel_ended(winner: String)
signal changed

const MAX_HEAT := 3
const HAND_SIZE := 5
const PLATE_SIZE := 5
const SERVE_COST := 1
const MAX_HYPE := 100
## Ingredients placed in Recipe Book order.
const PERFECT_ORDER_MULT := 1.5

## Signature Dish (GDD §4.5): appears in hand when Hype is full, once per duel.
static var SIGNATURE_CARD: CardDef = _make_signature_card()


class Fighter:
	var confidence: int
	var max_confidence: int
	var composure := 0
	## Player only.
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
var recipes: Array[RecipeDef]

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard: Array[CardInstance] = []
var plate: Array[CardInstance] = []
## Cards removed from this duel (played Signature Dish).
var exhausted: Array[CardInstance] = []

var hype := 0
var turn := 0
## "player" | "won" | "lost"
var phase := "player"
var served_this_turn := false
## Signature Dish card was handed out (once per duel).
var signature_given := false
## Signature Dish played; the next Serve is doubled.
var signature_armed := false
## Newest last; the HUD shows the tail.
var log_lines: PackedStringArray = []

var _intent_index := 0
var _next_uid := 0
var _rng: SeededRng


## opts: { confidence, max_confidence, hype, seed } — all optional.
func _init(deck: Array[CardDef], enemy_def_: EnemyDef, recipes_: Array[RecipeDef], opts := {}) -> void:
	var rng_seed: int = opts.get("seed", int(Time.get_unix_time_from_system() * 1000.0))
	_rng = SeededRng.new(rng_seed)
	var max_conf: int = opts.get("max_confidence", 60)
	player = Fighter.new(opts.get("confidence", max_conf), max_conf)
	enemy_def = enemy_def_
	enemy = Fighter.new(enemy_def.confidence, enemy_def.confidence)
	recipes = recipes_
	for def in deck:
		draw_pile.append(_instance(def))
	_rng.shuffle(draw_pile)
	_start_player_turn()
	# Starting Hype goes through _add_hype so a full meter hands out the Signature Dish.
	if opts.get("hype", 0) > 0:
		_add_hype(opts.hype)


# ---------------------------------------------------------------- queries

func intent() -> IntentDef:
	var p := enemy_def.pattern
	return p[_intent_index % p.size()]


## { ready: Array[RecipeDef], almost: Array[RecipeDef] }
func recipe_check() -> Dictionary:
	return RecipeMatch.check(recipes, plate)


func fighter(side: String) -> Fighter:
	return player if side == "player" else enemy


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


## { ok: bool, reason: String }
func can_play(uid: int) -> Dictionary:
	if phase != "player":
		return _fail("The duel is over.")
	var i := _hand_index(uid)
	if i < 0:
		return _fail("Card is not in hand.")
	var card := hand[i]
	if card.def.cost > player.heat:
		return _fail("Not enough Heat.")
	if card.def.is_ingredient() and plate.size() >= PLATE_SIZE:
		return _fail("The Plate is full.")
	return _ok()


func can_serve() -> Dictionary:
	if phase != "player":
		return _fail("The duel is over.")
	if served_this_turn:
		return _fail("Already served this turn.")
	if plate.is_empty():
		return _fail("The Plate is empty.")
	if player.heat < SERVE_COST:
		return _fail("Not enough Heat.")
	return _ok()


# ---------------------------------------------------------------- actions

func play(uid: int) -> Dictionary:
	var result := can_play(uid)
	if not result.ok:
		return result
	var card: CardInstance = hand.pop_at(_hand_index(uid))
	player.heat -= card.def.cost

	if card.def.is_ingredient():
		plate.append(card)
		_say("%s goes on the Plate." % card.def.name)
	else:
		(exhausted if card.def.exhaust else discard).append(card)
		_say("Apis uses %s." % card.def.name)
	if card.def.special == "signature":
		signature_armed = true
		_say("Signature Dish ready! Next Serve ×2.")
	card_played.emit(card)
	_apply_effects(card.def.effects, 0, 1.0)
	changed.emit()
	return _ok()


## Serve the whole Prep Board. The Recipe Book is closed during a duel, so the game cooks
## the best matching dish (RecipeMatch.best_dish). Tests use serve_as() to force one.
func serve() -> Dictionary:
	var result := can_serve()
	if not result.ok:
		return result
	return _do_serve(RecipeMatch.best_dish(recipes, plate))


## Force a recipe by id, or "" for an Improvised Dish (tests / debug).
func serve_as(recipe_id: String) -> Dictionary:
	var result := can_serve()
	if not result.ok:
		return result
	var recipe: RecipeDef = null
	if recipe_id != "":
		for r: RecipeDef in recipe_check().ready:
			if r.id == recipe_id:
				recipe = r
		if recipe == null:
			return _fail("That recipe does not match the Plate.")
	return _do_serve(recipe)


func end_turn() -> Dictionary:
	if phase != "player":
		return _fail("The duel is over.")
	# Hand is discarded except Retain cards; the Plate stays (GDD §4.2 step 4).
	var kept: Array[CardInstance] = []
	for c in hand:
		(kept if c.def.retain else discard).append(c)
	hand = kept
	_end_of_turn_decay("player")
	_enemy_turn()
	if phase == "player":
		_start_player_turn()
	changed.emit()
	return _ok()


# ---------------------------------------------------------------- serve

func _do_serve(recipe: RecipeDef) -> Dictionary:
	var perfect := recipe != null and RecipeMatch.in_order(recipe, plate)

	player.heat -= SERVE_COST
	served_this_turn = true
	var served := plate
	plate = []
	var quality := RecipeMatch.plate_quality(served)
	var enemy_before := enemy.confidence + enemy.composure

	# Effect multiplier: Perfect Order ×1.5, Signature Dish ×2, Burnt ×0.5 (all stack).
	var mult := PERFECT_ORDER_MULT if perfect else 1.0
	var signature := signature_armed
	if signature:
		mult *= 2.0
		signature_armed = false
	var burnt := player.stacks("burnt") > 0
	if burnt:
		mult *= 0.5
		_add_status("player", "burnt", -1)
		_say("Burnt! This Serve is halved.")

	var dish_name := recipe.name if recipe else "Improvised Dish"
	if signature:
		signature_served.emit(dish_name)
	dish_revealed.emit(recipe, perfect, signature, burnt)

	if recipe:
		_say("SERVE! %s (+%d Quality)%s%s" % [recipe.name, quality,
				" Perfect Order!" if perfect else "", " ×2" if signature else ""])
		# Recipe effect = base value + total Plate Quality (GDD §4.4), on the headline effect.
		_apply_effects(recipe.effects, quality, mult)
	else:
		_say("Improvised Dish: %d ingredients.%s" % [served.size(), " ×2" if signature else ""])
		_apply_effects([EffectDef.make(EffectDef.Kind.PRESSURE, 2 * served.size())], 0, mult)
	# The Signature Dish spends the crowd; otherwise a recipe Serve builds Hype.
	if signature:
		hype = 0
	elif recipe:
		_add_hype(recipe.hype)

	discard.append_array(served)
	var dealt := enemy_before - (enemy.confidence + enemy.composure)
	dish_served.emit(recipe, dealt, quality, served.size())
	changed.emit()
	return _ok()


# ---------------------------------------------------------------- turn flow

func _start_player_turn() -> void:
	turn += 1
	player.composure = 0
	served_this_turn = false
	_tick_spicy("player")
	if phase != "player":
		return
	player.heat = MAX_HEAT
	var inspired := player.stacks("inspired")
	if inspired > 0:
		_add_status("player", "inspired", -inspired)
	_draw(HAND_SIZE + inspired)
	turn_started.emit(turn)


func _enemy_turn() -> void:
	# Composure fades at the start of its owner's turn (GDD §4.1).
	enemy.composure = 0
	_tick_spicy("enemy")
	if phase != "player":
		return

	var it := intent()
	_say("%s: %s!" % [enemy_def.name, it.label])
	if it.has_attack():
		_deal_pressure("player", pressure_from("enemy", it.attack))
	if phase != "player":
		return
	if it.block > 0:
		_gain_composure("enemy", it.block)
	if it.has_status():
		var side := "player" if it.status_target == IntentDef.StatusTarget.PLAYER else "enemy"
		_add_status(side, it.status, it.status_amount)
	enemy_acted.emit(it)
	_intent_index += 1
	_end_of_turn_decay("enemy")


## Spicy: lose X Confidence (ignores Composure), then X − 1.
func _tick_spicy(side: String) -> void:
	var x := fighter(side).stacks("spicy")
	if x <= 0:
		return
	_say("%s feels the burn: −%d" % ["Apis" if side == "player" else enemy_def.name, x])
	_lose_confidence(side, x, "spicy")
	_add_status(side, "spicy", -1)


## Flustered and Rattled count down at the end of their owner's turn.
func _end_of_turn_decay(side: String) -> void:
	for id in ["flustered", "rattled"]:
		if fighter(side).stacks(id) > 0:
			_add_status(side, id, -1)


# ---------------------------------------------------------------- effects

## `bonus` is added to the first effect's amount (recipe Quality); `mult` scales it all.
func _apply_effects(effects: Array[EffectDef], bonus: int, mult: float) -> void:
	for i in effects.size():
		if phase != "player":
			return
		var e := effects[i]
		var scaled := floori((e.amount + (bonus if i == 0 else 0)) * mult)
		match e.kind:
			EffectDef.Kind.PRESSURE:
				_deal_pressure("enemy", pressure_from("player", scaled))
			EffectDef.Kind.COMPOSURE:
				_gain_composure("player", scaled)
			EffectDef.Kind.HEAL:
				_heal(scaled)
			EffectDef.Kind.DRAW:
				_draw(e.amount)
			EffectDef.Kind.HYPE:
				_add_hype(e.amount)
			EffectDef.Kind.STATUS:
				var side := "player" if e.target == EffectDef.Target.SELF else "enemy"
				_add_status(side, e.status, maxi(1, scaled))
			EffectDef.Kind.CLEANSE:
				_cleanse(e.amount)


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
	if f.confidence == 0 and phase == "player":
		phase = "won" if target == "enemy" else "lost"
		_say("%s gives up!" % enemy_def.name if target == "enemy" else "Apis loses heart...")
		duel_ended.emit("player" if target == "enemy" else "enemy")


func _add_status(side: String, id: String, delta: int) -> void:
	var s := fighter(side).statuses
	var v: int = s.get(id, 0) + delta
	if v > 0:
		s[id] = v
	else:
		s.erase(id)
	if delta > 0:
		status_applied.emit(side, id, delta)


func _cleanse(count: int) -> void:
	for _n in count:
		var found := ""
		for id in StatusDefs.CLEANSE_ORDER:
			if player.stacks(id) > 0:
				found = id
				break
		if found == "":
			return
		player.statuses.erase(found)
		_say("Cleansed %s." % found)


func _gain_composure(target: String, amount: int) -> void:
	fighter(target).composure += amount
	composure_gained.emit(target, amount)


func _heal(amount: int) -> void:
	player.confidence = mini(player.max_confidence, player.confidence + amount)


func _add_hype(amount: int) -> void:
	hype = mini(MAX_HYPE, hype + amount)
	if hype >= MAX_HYPE and not signature_given:
		signature_given = true
		hand.append(_instance(SIGNATURE_CARD))
		_say("The crowd goes wild! Signature Dish unlocked!")
		signature_ready.emit()


func _draw(n: int) -> void:
	for _i in n:
		if draw_pile.is_empty():
			if discard.is_empty():
				return
			draw_pile = discard
			_rng.shuffle(draw_pile)
			discard = []
		hand.append(draw_pile.pop_back())


# ---------------------------------------------------------------- helpers

func _instance(def: CardDef) -> CardInstance:
	var c := CardInstance.new(_next_uid, def)
	_next_uid += 1
	return c


func _hand_index(uid: int) -> int:
	for i in hand.size():
		if hand[i].uid == uid:
			return i
	return -1


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
