class_name EnemyDef
extends Resource
## A rival chef. One .tres per rival in res://data/enemies/.

@export var id := ""
@export var name := ""
@export var title := ""
## Shown in the Almanac once a duel with this rival ended (GRAND_DESIGN §6).
@export_multiline var gimmick := ""
@export var confidence := 30
## Grand final / boss duel: Boss appearance sting, and no Battle_Theme (boss theme comes later).
@export var boss := false

@export_group("Drafting AI (GRAND_DESIGN §3)")
## The rival's own deck. With a deck and an AI profile the rival drafts by the player's rules;
## without, it falls back to the intent pattern below.
@export var deck: DeckDef
## Recipe Books the rival has mastered (BookDef ids).
@export var books: PackedStringArray = ["basics"]
## Heat per turn (early rivals get less).
@export_range(1, 5) var max_heat := 3
## Cards drawn per turn.
@export_range(1, 8) var hand_size := 5
@export var ai: AiProfile
## Chef's Flow: Perfect Serves needed for each modifier (GRAND_DESIGN §5.4); the last repeats.
@export var flow_thresholds: PackedInt32Array = [3, 4, 5]

@export_group("Intent pattern (old)")
## Intents cycle in order. Used only when the rival has no deck/AI (tests, fallback).
@export var pattern: Array[IntentDef] = []


## True when the rival drafts with its own Kitchen (GRAND_DESIGN §3).
func drafts() -> bool:
	return deck != null and ai != null
