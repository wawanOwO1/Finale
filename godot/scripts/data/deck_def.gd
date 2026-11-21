class_name DeckDef
extends Resource
## A deck list. Duplicates = several copies. One .tres per deck in res://data/decks/.

@export var id := ""
@export var cards: Array[CardDef] = []
