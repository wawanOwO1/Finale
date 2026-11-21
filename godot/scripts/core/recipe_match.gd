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


## Perfect Order: the recipe's ingredients sit on the board in Recipe Book order (others may
## sit in between). Greedy subsequence matching is optimal here.
static func in_order(recipe: RecipeDef, plate: Array[CardInstance]) -> bool:
	var r := 0
	for c in plate:
		if r < recipe.requires.size() and fits(recipe.requires[r], c):
			r += 1
	return r == recipe.requires.size()


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
