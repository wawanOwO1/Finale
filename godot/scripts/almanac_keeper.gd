class_name AlmanacKeeper
extends Node
## Keeps the Almanac (GRAND_DESIGN §6): loads it at start, feeds it from each duel, saves it
## whenever something new is discovered. Lives in main.tscn (node "AlmanacKeeper").
## The Almanac window itself is the Almanac node in duel_ui.tscn.

## Discovery persists across runs here. Tests point it at a throwaway file.
@export var save_path := "user://almanac.save"
## Off = keep discoveries for this session only (nothing written).
@export var persist := true
## Dev: start with everything discovered (ignores the save file, writes nothing).
@export var reveal_all := false

var almanac: Almanac


func _ready() -> void:
	if reveal_all:
		persist = false
	almanac = Almanac.load_from(save_path) if persist else Almanac.new()
	if reveal_all:
		_reveal_all()
	almanac.discovered.connect(func(_kind: String, _id: String) -> void: save())


## Your deck and books, before the Recipe Book opens.
func prepare(deck: Array[CardDef], books: Array[RecipeDef]) -> void:
	almanac.prepare(deck, books)


func watch(d: Duel) -> void:
	almanac.watch(d)
	d.duel_ended.connect(func(_winner: String) -> void: save())


func save() -> void:
	if persist:
		almanac.save(save_path)


func _reveal_all() -> void:
	for c: CardDef in GameDB.all("cards"):
		almanac.discover_card(c.id)
	for r: RecipeDef in GameDB.all("recipes"):
		almanac.discover_recipe(r.id, Almanac.MASTERED)
	for e: EnemyDef in GameDB.all("enemies"):
		almanac.finish_rival(e.id)
		for w in [e.weakness, e.weakness_phase2]:
			if w != RecipeDef.HOME:
				almanac.reveal_weakness(e.id, w)
	almanac.unseen.clear()
