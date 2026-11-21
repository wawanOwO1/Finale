extends Node
## Graybox entry point: one duel. Pick the setup in the Inspector (select Main) instead of
## the old URL params (?enemy=rosa, ?deck=dev, ?hype=100).

@export_enum("tony", "rosa") var enemy_id := "tony"
## Starter deck + status cards and all four Recipe Books.
@export var dev_deck := false
## 100 = Signature Dish in hand from turn 1.
@export_range(0, 100) var start_hype := 0

@onready var stage: Stage = $Stage
@onready var ui: DuelUI = $DuelUI

var duel: Duel


func _ready() -> void:
	ui.restart_requested.connect(_start_duel)
	_start_duel()


func _start_duel() -> void:
	var books: PackedStringArray = GameDB.ALL_BOOKS if dev_deck else PackedStringArray(["basics"])
	var recipes := GameDB.book_recipes(books)
	stage.set_plate([])
	await ui.show_cookbook(recipes)
	duel = Duel.new(GameDB.deck("dev" if dev_deck else "starter"), GameDB.enemy(enemy_id), recipes,
			{hype = start_hype})
	# Visuals listen to the duel's signals; the duel never knows about them (GDD §9).
	duel.changed.connect(_sync_plate)
	duel.confidence_lost.connect(func(target: String, _amount: int, _source: String) -> void:
		stage.hit("rival" if target == "enemy" else "player"))
	ui.bind(duel)
	_sync_plate()


func _sync_plate() -> void:
	var tags: Array = []
	for c in duel.plate:
		tags.append(c.def.first_tag())
	stage.set_plate(tags)
