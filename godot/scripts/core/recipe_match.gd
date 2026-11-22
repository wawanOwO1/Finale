class_name RecipeMatch
## Recipe matching against the Plate / Prep Board. Pure functions.


static func fits(req: String, card: CardInstance) -> bool:
	if req.begins_with("card:"):
		return card.def.id == req.substr(5)
	return card.def.tags.has(req)


## How many requirements are left unmet when each Plate ingredient may fill at most one slot.
## Sizes are tiny (≤6 slots, ≤6 ingredients), so plain backtracking is fine and handles
## multi-tag ingredients and duplicates like VEGGIE + VEGGIE correctly.
static func missing_count(recipe: RecipeDef, plate: Array[CardInstance]) -> int:
	var used: Array[bool] = []
	used.resize(plate.size())
	used.fill(false)
	var state := {best = recipe.requires.size()}
	_search(recipe.requires, plate, used, 0, 0, state)
	return state.best


static func _search(reqs: PackedStringArray, plate: Array[CardInstance], used: Array[bool],
		i: int, missing: int, state: Dictionary) -> void:
	if missing >= state.best:
		return
	if i == reqs.size():
		state.best = missing
		return
	for p in plate.size():
		if not used[p] and fits(reqs[i], plate[p]):
			used[p] = true
			_search(reqs, plate, used, i + 1, missing, state)
			used[p] = false
			if state.best == 0:
				return
	_search(reqs, plate, used, i + 1, missing + 1, state)


## { ready: Array[RecipeDef] (servable now), almost: Array[RecipeDef] (one slot short) }
static func check(known: Array[RecipeDef], plate: Array[CardInstance]) -> Dictionary:
	var ready: Array[RecipeDef] = []
	var almost: Array[RecipeDef] = []
	for r in known:
		var m := missing_count(r, plate)
		if m == 0:
			ready.append(r)
		elif m == 1:
			almost.append(r)
	return {ready = ready, almost = almost}


static func plate_quality(plate: Array[CardInstance]) -> int:
	var sum := 0
	for c in plate:
		sum += c.def.quality
	return sum


## Perfect Order (ART_DIRECTION §6.2): the stack starts with the recipe's steps exactly, in
## Recipe Book order. Anything placed after the last step is Garnish and does not break it.
static func in_order(recipe: RecipeDef, plate: Array[CardInstance]) -> bool:
	var n := recipe.requires.size()
	if plate.size() < n:
		return false
	for i in n:
		if not fits(recipe.requires[i], plate[i]):
			return false
	return true


## True when the whole stack is the start of the recipe's step list (still on the path).
static func is_prefix(recipe: RecipeDef, stack: Array[CardInstance]) -> bool:
	if stack.size() > recipe.requires.size():
		return false
	for i in stack.size():
		if not fits(recipe.requires[i], stack[i]):
			return false
	return true


## Would placing `card` on top of `stack` keep it on the path of some known recipe?
static func accepts_next(known: Array[RecipeDef], stack: Array[CardInstance], card: CardInstance) -> bool:
	var next: Array[CardInstance] = stack.duplicate()
	next.append(card)
	for r in known:
		if is_prefix(r, next):
			return true
	return false


## The Order Ticket over a station (ART_DIRECTION §6.3).
## { state: "empty" | "building" | "perfect" | "cooked" | "improvised", recipe: RecipeDef or null,
##   steps: Array of { req: String, state: "done" | "next" | "todo" }, garnish: int }
## A finished dish wins over one still being built; while building, the recipe closest to done
## (then the strongest) is shown with its next step.
static func ticket(known: Array[RecipeDef], stack: Array[CardInstance]) -> Dictionary:
	var out := {state = "empty", recipe = null, steps = [], garnish = 0}
	if stack.is_empty():
		return out
	var dish := best_dish(known, stack)
	if dish:
		var perfect := in_order(dish, stack)
		out.state = "perfect" if perfect else "cooked"
		out.recipe = dish
		out.garnish = stack.size() - dish.requires.size()
		for req in dish.requires:
			out.steps.append({req = req, state = "done"})
		return out
	var best: RecipeDef = null
	for r in known:
		if not is_prefix(r, stack):
			continue
		if best == null or r.requires.size() - stack.size() < best.requires.size() - stack.size() 				or (r.requires.size() == best.requires.size() and r.power() > best.power()):
			best = r
	if best == null:
		out.state = "improvised"
		return out
	out.state = "building"
	out.recipe = best
	for i in best.requires.size():
		var st := "done" if i < stack.size() else ("next" if i == stack.size() else "todo")
		out.steps.append({req = best.requires[i], state = st})
	return out


## The dish the board cooks into: a Perfect Order match first, then more slots, then power.
## Returns null when nothing matches (Improvised Dish).
static func best_dish(known: Array[RecipeDef], plate: Array[CardInstance]) -> RecipeDef:
	var best: RecipeDef = null
	var best_key: Array[int] = []
	for r in known:
		if missing_count(r, plate) != 0:
			continue
		var key: Array[int] = [int(in_order(r, plate)), r.requires.size(), r.power()]
		# Strictly better only: ties keep the earlier recipe (stable, like the TS sort).
		if best == null or _better(key, best_key):
			best = r
			best_key = key
	return best


static func _better(a: Array[int], b: Array[int]) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] > b[i]
	return false
