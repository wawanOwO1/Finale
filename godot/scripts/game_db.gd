class_name GameDB
## Loads every content .tres under res://data/ once and looks it up by id.
## Adding content = adding a .tres file (right-click the folder → New Resource…), no code.

const DATA_DIRS := {
	cards = "res://data/cards",
	recipes = "res://data/recipes",
	enemies = "res://data/enemies",
	books = "res://data/books",
	decks = "res://data/decks",
}
## Book order used for "all books" (dev deck).
const ALL_BOOKS: PackedStringArray = ["basics", "grill", "spice", "comfort"]

static var _tables := {}


static func card(id: String) -> CardDef:
	return _lookup("cards", id)


static func recipe(id: String) -> RecipeDef:
	return _lookup("recipes", id)


static func enemy(id: String) -> EnemyDef:
	return _lookup("enemies", id)


static func book(id: String) -> BookDef:
	return _lookup("books", id)


static func deck(id: String) -> Array[CardDef]:
	var d: DeckDef = _lookup("decks", id)
	return d.cards.duplicate() if d else ([] as Array[CardDef])


static func all(table: String) -> Array:
	_ensure_loaded()
	return _tables[table].values()


## Recipes of several books, in book order.
static func book_recipes(book_ids: PackedStringArray) -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	for id in book_ids:
		var b := book(id)
		if b:
			out.append_array(b.recipes)
	return out


static func _lookup(table: String, id: String) -> Resource:
	_ensure_loaded()
	var res: Resource = _tables[table].get(id)
	if res == null:
		push_error("GameDB: no %s with id '%s'" % [table, id])
	return res


static func _ensure_loaded() -> void:
	if not _tables.is_empty():
		return
	for table: String in DATA_DIRS:
		var into := {}
		var dir: String = DATA_DIRS[table]
		for file in DirAccess.get_files_at(dir):
			# Exported builds list "x.tres.remap"; load() still takes the original path.
			file = file.trim_suffix(".remap")
			if not (file.ends_with(".tres") or file.ends_with(".res")):
				continue
			var res := load(dir.path_join(file))
			if res and "id" in res and res.id != "":
				into[res.id] = res
			else:
				push_warning("GameDB: %s has no id, skipped" % dir.path_join(file))
		_tables[table] = into
