class_name Almanac
extends RefCounted
## What the player has discovered (GRAND_DESIGN §6). Knowledge, not power: it never changes a
## duel, so it may persist across runs (`user://almanac.save`) without being meta-progression.
## Pure data + rules; AlmanacKeeper (node in main.tscn) feeds it from duels and saves it.

const VERSION := 1
## Recipe source: its book is mastered (shown in full).
const MASTERED := "mastered"

## Something new was discovered. kind: "card" | "recipe" | "rival".
signal discovered(kind: String, id: String)

## Card id -> true.
var cards := {}
## Recipe id -> MASTERED or the id of the rival that served it ("Seen from Tony").
var recipes := {}
## Rival id -> { finished: bool } (gimmick shows once a duel with them ended).
var rivals := {}
## Rival id -> recipe ids they served, first serve first.
var served := {}
## "kind:id" -> true for entries not looked at yet (the NEW badge).
var unseen := {}


# ================================================================ queries

func knows_card(id: String) -> bool:
	return cards.has(id)


func knows_recipe(id: String) -> bool:
	return recipes.has(id)


## MASTERED, a rival id, or "" when unknown.
func recipe_source(id: String) -> String:
	return recipes.get(id, "")


func knows_rival(id: String) -> bool:
	return rivals.has(id)


func rival_finished(id: String) -> bool:
	return rivals.has(id) and rivals[id].get("finished", false)


func served_by(rival_id: String) -> PackedStringArray:
	return PackedStringArray(served.get(rival_id, []))


func is_new(kind: String, id: String) -> bool:
	return unseen.has("%s:%s" % [kind, id])


func mark_seen(kind: String, id: String) -> void:
	unseen.erase("%s:%s" % [kind, id])


func count() -> int:
	return cards.size() + recipes.size() + rivals.size()


# ================================================================ discovery

func discover_card(id: String) -> bool:
	if id == "" or cards.has(id):
		return false
	cards[id] = true
	_new("card", id)
	return true


## A mastered book always wins over "Seen from <rival>".
func discover_recipe(id: String, source: String) -> bool:
	var had: String = recipes.get(id, "")
	if had == MASTERED or (had != "" and source != MASTERED):
		return false
	recipes[id] = source
	if had == "":
		_new("recipe", id)
	return had == ""


func meet_rival(id: String) -> bool:
	if rivals.has(id):
		return false
	rivals[id] = {finished = false}
	_new("rival", id)
	return true


## A duel with this rival ended: their gimmick is revealed.
func finish_rival(id: String) -> void:
	meet_rival(id)
	if not rivals[id].finished:
		rivals[id].finished = true
		unseen["rival:%s" % id] = true


## The rival served this recipe: it is "Seen from <rival>" if not mastered yet.
func record_serve(rival_id: String, recipe_id: String) -> void:
	var list: Array = served.get(rival_id, [])
	if not list.has(recipe_id):
		list.append(recipe_id)
		served[rival_id] = list
	discover_recipe(recipe_id, rival_id)


## Before a duel (also the pre-duel Recipe Book): your deck and your books.
func prepare(deck: Array[CardDef], books: Array[RecipeDef]) -> void:
	for c in deck:
		if c.special != "signature":
			discover_card(c.id)
	for r in books:
		discover_recipe(r.id, MASTERED)


## Listen to one duel: rival met now, their dishes as they serve, gimmick when it ends.
func watch(d: Duel) -> void:
	var rival := d.enemy_def.id
	meet_rival(rival)
	d.card_played.connect(func(side: String, card: CardInstance) -> void:
		if side == "player" and card.def.special != "signature":
			discover_card(card.def.id))
	d.dish_served.connect(func(side: String, recipe: RecipeDef, _p: int, _q: int, _n: int) -> void:
		if side == "enemy" and recipe:
			record_serve(rival, recipe.id))
	d.duel_ended.connect(func(_winner: String) -> void: finish_rival(rival))


func _new(kind: String, id: String) -> void:
	unseen["%s:%s" % [kind, id]] = true
	discovered.emit(kind, id)


# ================================================================ combination finder (§6.3)

## Can a finder pick (tag "FAT" or "card:beef") fill this recipe slot? A tag pick also fills a
## key-ingredient slot of that tag, and an ingredient pick fills any slot of its tags.
static func pick_fits(pick: String, slot: String) -> bool:
	if pick == slot:
		return true
	if pick.begins_with("card:") == slot.begins_with("card:"):
		return false
	var card_id := (pick if pick.begins_with("card:") else slot).substr(5)
	var tag := slot if pick.begins_with("card:") else pick
	var def := GameDB.card(card_id)
	return def != null and def.tags.has(tag)


## Which slots the picks fill, each pick in its own slot; empty when some pick does not fit.
static func cover(recipe: RecipeDef, picks: PackedStringArray) -> Array[bool]:
	var used: Array[bool] = []
	used.resize(recipe.requires.size())
	used.fill(false)
	return used if _assign(recipe.requires, picks, 0, used) else ([] as Array[bool])


static func _assign(slots: PackedStringArray, picks: PackedStringArray, i: int, used: Array[bool]) -> bool:
	if i == picks.size():
		return true
	for s in slots.size():
		if not used[s] and pick_fits(picks[i], slots[s]):
			used[s] = true
			if _assign(slots, picks, i + 1, used):
				return true
			used[s] = false
	return false


## Recipes the picks fit into: [{ recipe, covered: Array[bool] }], in the given order.
static func find(pool: Array[RecipeDef], picks: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in pool:
		var c := cover(r, picks)
		if not c.is_empty():
			out.append({recipe = r, covered = c})
	return out


## Recipes with a slot this ingredient fills ("Used in").
static func uses_of(card: CardDef, pool: Array[RecipeDef]) -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	for r in pool:
		for slot in r.requires:
			if slot == "card:" + card.id or card.tags.has(slot):
				out.append(r)
				break
	return out


# ================================================================ save

func to_dict() -> Dictionary:
	return {version = VERSION, cards = cards.keys(), recipes = recipes, rivals = rivals,
			served = served, unseen = unseen.keys()}


static func from_dict(data: Dictionary) -> Almanac:
	var a := Almanac.new()
	for id in data.get("cards", []):
		a.cards[str(id)] = true
	var rec: Dictionary = data.get("recipes", {})
	for id in rec:
		a.recipes[str(id)] = str(rec[id])
	var riv: Dictionary = data.get("rivals", {})
	for id in riv:
		a.rivals[str(id)] = {finished = bool((riv[id] as Dictionary).get("finished", false))}
	var srv: Dictionary = data.get("served", {})
	for id in srv:
		a.served[str(id)] = Array(srv[id]).map(func(x: Variant) -> String: return str(x))
	for k in data.get("unseen", []):
		a.unseen[str(k)] = true
	return a


func save(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Almanac: cannot write %s" % path)
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	return true


## A missing or broken file gives an empty Almanac.
static func load_from(path: String) -> Almanac:
	if not FileAccess.file_exists(path):
		return Almanac.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("Almanac: %s is not valid, starting empty" % path)
		return Almanac.new()
	return from_dict(data)
