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
## Cuisine (GDD §4.11): rivals shrug off their Specialty and are weak to one other cuisine.
## HOME is neutral (never a weakness, specialty or reputation).
@export_enum("HOME", "ASIAN", "MEXICAN", "ITALIAN", "FRENCH", "AMERICAN") var cuisine := "HOME"
@export_multiline var text := ""

## Every cuisine (GDD §4.11). HOME first: the neutral one.
const HOME := "HOME"
const CUISINES: PackedStringArray = ["HOME", "ASIAN", "MEXICAN", "ITALIAN", "FRENCH", "AMERICAN"]


## "Asian", "Home", … for HUD text.
static func cuisine_name(c: String) -> String:
	return c.capitalize() if c != "" else "None"


func power() -> int:
	var sum := 0
	for e in effects:
		sum += e.amount
	return sum
