class_name BookDef
extends Resource
## A Recipe Book (cookbook). One .tres per book in res://data/books/.

@export var id := ""
@export var name := ""
@export var recipes: Array[RecipeDef] = []
