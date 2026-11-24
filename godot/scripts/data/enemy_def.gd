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

@export_group("Cuisine (GDD §4.11)")
## Home cuisine: your dishes of it hit for less ("Seen it before"). Always public.
@export_enum("HOME", "ASIAN", "MEXICAN", "ITALIAN", "FRENCH", "AMERICAN") var specialty := "HOME"
## The cuisine they never learned: your dishes of it hit harder and Stump them. "???" in the
## Almanac until you hit it once. HOME = no weakness.
@export_enum("HOME", "ASIAN", "MEXICAN", "ITALIAN", "FRENCH", "AMERICAN") var weakness := "HOME"
## Pre-duel hint at the weakness (shown on the rival's HUD badge while it is still unknown).
@export_multiline var weakness_hint := ""
## Boss: below `phase2_at` of their Confidence the weakness switches to this. HOME = never.
@export_enum("HOME", "ASIAN", "MEXICAN", "ITALIAN", "FRENCH", "AMERICAN") var weakness_phase2 := "HOME"
@export_range(0.0, 1.0, 0.05) var phase2_at := 0.5
## Élodie: after this many weakness hits she has "studied" it and it stops working. 0 = never.
@export_range(0, 10) var studies_weakness_after := 0
## Elites and the Boss come prepared: your run Reputation counts as an extra Specialty.
@export var knows_reputation := false

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
