class_name RecipeDef
extends Resource
## A recipe. One .tres per recipe in res://data/recipes/.

@export var id := ""
@export var name := ""
## Id of the BookDef it belongs to.
@export var book := ""
## Slots in Recipe Book order (placing them in this order = Perfect Order ×1.5).
## Each entry is a tag ("FAT") or a key ingredient by card id ("card:beef").
@export var requires: PackedStringArray = []
## The first effect also gets + total Plate Quality.
@export var effects: Array[EffectDef] = []
## Hype gained when served (GDD §4.4).
@export var hype := 25
@export_multiline var text := ""


func power() -> int:
	var sum := 0
	for e in effects:
		sum += e.amount
	return sum
