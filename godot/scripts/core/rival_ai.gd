class_name RivalAI
extends RefCounted
## The drafting rival's brain (GRAND_DESIGN §3.2). Pure functions over a Duel: list one side's
## legal actions, score each with an AiProfile, pick the best. One action per call, so the
## Turn Director can show every step. It can play either side (`side`, default "enemy"), which
## tests/sim.gd uses to pit a smart Apis against each rival for balancing.
##
## Fair by design (GRAND_DESIGN §4.4): about the other side it reads only what is public —
## Confidence, Composure, statuses, Hype and HOW MANY cards sit on its stations. Never the
## other side's hand or station contents.

## Safety cap on actions in one turn.
const MAX_STEPS := 12
## Added to any action that wins the duel on the spot.
const LETHAL := 1000.0
## Pressure on a ready station at which the rival looks Confident (mood, GRAND_DESIGN §3.4).
const CONFIDENT_AT := 10
## Scores this close count as a tie, broken by the kitchen's own ai_rng stream (GRAND_DESIGN §4.3).
const TIE := 0.05


## Best next action for `side`:
## { kind: "place", uid, station } | { kind: "technique", uid } | { kind: "serve", station }
## | { kind: "end" }, each with its `score`. `prof` defaults to the rival's AiProfile.
static func choose(d: Duel, side := "enemy", prof: AiProfile = null) -> Dictionary:
	var p := prof if prof else profile(d)
	var k := d.kitchen(side)
	var pick := {best = {kind = "end", score = p.end_threshold}, ties = 1, rng = k.ai_rng}
	for c in k.hand:
		if c.def.is_ingredient():
			for s in Duel.STATIONS:
				if d.can_play(c.uid, s, side).ok:
					_consider(pick, {kind = "place", uid = c.uid, station = s, score = _place_score(d, c, s, side, p)})
		elif d.can_play(c.uid, -1, side).ok:
			_consider(pick, {kind = "technique", uid = c.uid, score = _technique_score(d, c, side, p)})
	for s in Duel.STATIONS:
		if d.can_serve(s, side).ok:
			_consider(pick, {kind = "serve", station = s, score = _serve_score(d, s, side, p)})
	return pick.best


## Mood shown over the rival's head on Apis's turn (replaces the old intent, GRAND_DESIGN §3.4):
## "confident" = a station could be served for a big hit, "wary" = the rival is low,
## "" = nothing to show. Vague on purpose: no numbers, no ingredients.
static func mood(d: Duel) -> String:
	if d.over() or not d.drafting():
		return ""
	var p := profile(d)
	var k := d.kitchen("enemy")
	for s in Duel.STATIONS:
		var st := k.stack(s)
		if st.is_empty():
			continue
		var sv := serve_preview(d, st, "enemy", p)
		if sv.recipe != null and sv.pressure >= CONFIDENT_AT:
			return "confident"
	if d.enemy.confidence <= d.enemy.max_confidence * 0.4:
		return "wary"
	return ""


static func profile(d: Duel) -> AiProfile:
	return d.enemy_def.ai if d.enemy_def.ai else AiProfile.new()


## What serving `stack` would do right now: { recipe, perfect, pressure, value, lethal }.
static func serve_preview(d: Duel, stack: Array[CardInstance], side := "enemy", prof: AiProfile = null) -> Dictionary:
	var p := prof if prof else profile(d)
	var k := d.kitchen(side)
	var recipe := RecipeMatch.best_dish(k.recipes, stack)
	var perfect := recipe != null and RecipeMatch.in_order(recipe, stack)
	var mult := d.perfect_mult(side) if perfect else 1.0
	if k.signature_armed:
		mult *= 2.0
	if d.fighter(side).stacks("burnt") > 0:
		mult *= 0.5
	var out: Dictionary
	if recipe:
		out = _effects_value(d, recipe.effects, d.dish_quality(recipe, stack, side), mult, side, p)
	else:
		out = _effects_value(d, [EffectDef.make(EffectDef.Kind.PRESSURE, 2 * stack.size())], 0, mult, side, p)
	# Hot Pan: flat Pressure on top of every Serve.
	if d.serve_bonus(side) > 0:
		var extra := d.pressure_from(side, d.serve_bonus(side))
		var foe := d.fighter(Duel._other(side))
		out.pressure += extra
		out.value += extra * p.w_attack
		out.lethal = out.pressure - foe.composure >= foe.confidence
	out.recipe = recipe
	out.perfect = perfect
	return out


# ---------------------------------------------------------------- scoring

static func _place_score(d: Duel, c: CardInstance, s: int, side: String, p: AiProfile) -> float:
	var k := d.kitchen(side)
	var before := k.stack(s)
	var after: Array[CardInstance] = before.duplicate()
	after.append(c)
	var score: float = _effects_value(d, c.def.effects, 0, 1.0, side, p).value - c.def.cost * 0.8
	score -= _reserve_penalty(d, c.def.cost, side)
	var dish := RecipeMatch.best_dish(k.recipes, after)
	if dish:
		var now := serve_preview(d, after, side, p)
		var was_value := 0.0
		if RecipeMatch.best_dish(k.recipes, before):
			was_value = serve_preview(d, before, side, p).value
		if was_value > 0.0:
			# Garnish on a finished dish: worth its extra Quality, never a reason to break it.
			return score + maxf(-3.0, (now.value - was_value) * 0.6)
		return score + 3.0 + now.value * 0.5 + (1.5 if now.perfect else 0.0)
	# On a recipe path in book order: the further along, and the more of the rest the hand
	# can still fill, the better. A path the hand can finish this turn is worth the most.
	var best_path := -INF
	for r in k.recipes:
		if not RecipeMatch.is_prefix(r, after):
			continue
		var rest := r.requires.slice(after.size())
		var fill := _fillable(rest, k.hand, c)
		var v := 1.5 + after.size() + fill * 1.5
		if fill == rest.size():
			v += 3.0 + r.power() * 0.2
		best_path = maxf(best_path, v)
	if best_path > -INF:
		return score + best_path
	if before.is_empty():
		return score + 0.2
	return score - 3.0


static func _technique_score(d: Duel, c: CardInstance, side: String, p: AiProfile) -> float:
	var k := d.kitchen(side)
	if c.def.special == "signature":
		if k.served_this_turn:
			return -1.0
		var best := 0.0
		for s in Duel.STATIONS:
			if not k.stack(s).is_empty():
				best = maxf(best, serve_preview(d, k.stack(s), side, p).value)
		return best - 1.0
	var v: float = _effects_value(d, c.def.effects, 0, 1.0, side, p).value
	return v - c.def.cost * 0.8 - _reserve_penalty(d, c.def.cost, side)


static func _serve_score(d: Duel, s: int, side: String, p: AiProfile) -> float:
	var k := d.kitchen(side)
	var st := k.stack(s)
	var sv := serve_preview(d, st, side, p)
	if sv.lethal:
		return LETHAL + sv.value
	if sv.recipe == null:
		# Improvised: only to empty a long dead-end stack.
		return sv.value * 0.5 - 2.0 if st.size() >= 4 else -5.0
	var score: float = sv.value + 2.0
	# Place first, serve last: if a card in hand still improves this dish, wait for it.
	for c in k.hand:
		if c.def.is_ingredient() and d.can_play(c.uid, s, side).ok and c.def.cost <= k.fighter.heat - Duel.SERVE_COST:
			var after: Array[CardInstance] = st.duplicate()
			after.append(c)
			if serve_preview(d, after, side, p).value > sv.value:
				score -= 6.0
				break
	# Patient chefs hold an out-of-order dish, unless they are in trouble.
	var me := d.fighter(side)
	var low := me.confidence <= me.max_confidence * 0.4
	if not sv.perfect and not low and st.size() < Duel.STATION_SIZE:
		score -= p.w_patience * 12.0
	return score


## Value of effects `side` would apply: { value, pressure, lethal }.
static func _effects_value(d: Duel, effects: Array, bonus: int, mult: float, side: String, p: AiProfile) -> Dictionary:
	var me := d.fighter(side)
	var foe := d.fighter(Duel._other(side))
	var danger := _danger(d, side)
	var value := 0.0
	var pressure := 0
	for i in effects.size():
		var e: EffectDef = effects[i]
		var scaled := floori((e.amount + (bonus if i == 0 else 0)) * mult)
		match e.kind:
			EffectDef.Kind.PRESSURE:
				var pr := d.pressure_from(side, scaled)
				pressure += pr
				value += pr * p.w_attack
			EffectDef.Kind.COMPOSURE:
				value += scaled * p.w_defend * danger
			EffectDef.Kind.HEAL:
				value += mini(scaled, me.max_confidence - me.confidence) * p.w_defend * danger
			EffectDef.Kind.DRAW:
				value += e.amount * 1.5
			EffectDef.Kind.HYPE:
				value += e.amount * 0.05
			EffectDef.Kind.STATUS:
				var n := maxi(1, scaled)
				if e.target == EffectDef.Target.SELF:
					value += n * 2.0 * maxf(p.w_attack, p.w_defend)
				else:
					value += n * 3.0 * p.w_debuff
			EffectDef.Kind.CLEANSE:
				for id in StatusDefs.CLEANSE_ORDER:
					if me.stacks(id) > 0:
						value += 3.0 * p.w_defend
						break
	var lethal := pressure - foe.composure >= foe.confidence
	return {value = value, pressure = pressure, lethal = lethal}


## How threatening the other side looks, from public info only (1 = calm, up to ~3).
static func _danger(d: Duel, side: String) -> float:
	var other := Duel._other(side)
	var me := d.fighter(side)
	var v := 1.0 + d.ingredient_count(other) / 6.0 + d.kitchen(other).hype / 100.0
	v += 1.0 - float(me.confidence) / me.max_confidence
	return v


## Keep 1 Heat for the Serve when a station already holds a dish.
static func _reserve_penalty(d: Duel, cost: int, side: String) -> float:
	var k := d.kitchen(side)
	if cost <= 0 or k.served_this_turn or k.fighter.heat - cost >= Duel.SERVE_COST:
		return 0.0
	for s in Duel.STATIONS:
		if RecipeMatch.best_dish(k.recipes, k.stack(s)) != null:
			return 6.0
	return 0.0


## How many of the remaining recipe steps the hand (minus `used`) can fill, in order.
static func _fillable(rest: PackedStringArray, hand: Array[CardInstance], used: CardInstance) -> int:
	var taken := {used.uid: true}
	var n := 0
	for req in rest:
		var found := false
		for c in hand:
			if not taken.has(c.uid) and c.def.is_ingredient() and RecipeMatch.fits(req, c):
				taken[c.uid] = true
				found = true
				break
		if not found:
			break
		n += 1
	return n


## Keeps the best action seen so far. Ties are a reservoir pick (each tied action equally
## likely) so a rival does not always fill the leftmost station first.
static func _consider(pick: Dictionary, b: Dictionary) -> void:
	var best: Dictionary = pick.best
	if b.score > best.score + TIE:
		pick.best = b
		pick.ties = 1
	elif b.score >= best.score - TIE and pick.rng:
		pick.ties += 1
		if pick.rng.index(pick.ties) == 0:
			pick.best = b


## Chef's Flow pick (GRAND_DESIGN §5.1): the offered modifier that suits this chef's profile
## best. Also picks for a bot Apis in tests/sim.gd.
static func pick_modifier(d: Duel, choices: Array[ModifierDef], side := "enemy", prof: AiProfile = null) -> ModifierDef:
	var p := prof if prof else profile(d)
	var best: ModifierDef = null
	var best_v := -INF
	for m in choices:
		var v := modifier_value(d, m, side, p)
		if v > best_v:
			best_v = v
			best = m
	return best


## Rough worth of one more stack of `m` for `side`, per turn.
static func modifier_value(d: Duel, m: ModifierDef, side: String, p: AiProfile) -> float:
	var k := d.kitchen(side)
	match m.id:
		"hot_pan":
			return m.amount * p.w_attack
		"steady_hands":
			return m.amount * 2.5 * p.w_defend * 2.0
		"encore":
			return m.amount * 10.0 * p.w_attack
		"extra_burner":
			return 2.0
		"prep_cook":
			return 2.5
		"crowd_favorite":
			return 1.5 if side == "player" else 0.3
		"spice_whisperer":
			return m.amount * 2.0 * p.w_debuff
		"free_move":
			# The rival AI does not move cards yet.
			return 1.0 if side == "player" else 0.1
		"mise_master":
			return 1.5
		"plating_pro":
			return 1.5 + k.hand_size * 0.1
	return 0.0
