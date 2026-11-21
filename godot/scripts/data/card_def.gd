class_name CardDef
extends Resource
## A card. One .tres per card in res://data/cards/ — edit them in the Inspector.

enum Type { INGREDIENT, TECHNIQUE }

## Valid ingredient tags (GDD §4.4).
const TAGS: PackedStringArray = ["PROTEIN", "CARB", "VEGGIE", "FAT", "DAIRY", "SPICE", "SAUCE"]

## Unique id; decks and recipes ("card:<id>") refer to it.
@export var id := ""
@export var name := ""
@export var type: Type = Type.INGREDIENT
@export_range(0, 5) var cost := 0

@export_group("Ingredient")
## One or more of CardDef.TAGS.
@export var tags: Array[String] = []
## 1–3 (GDD §4.4). Added to a recipe's headline effect when served.
@export_range(0, 3) var quality := 0

@export_group("")
## Ingredient: applied when placed on the Plate. Technique: applied when played.
@export var effects: Array[EffectDef] = []
@export_multiline var text := ""
## Stays in hand at End Turn.
@export var retain := false
## Removed from the duel once played instead of going to the discard pile.
@export var exhaust := false
## Special behaviour that is not a plain effect ("signature").
@export var special := ""


func is_ingredient() -> bool:
	return type == Type.INGREDIENT


func first_tag() -> String:
	return tags[0] if tags.size() > 0 else ""
