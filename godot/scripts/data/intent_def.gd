class_name IntentDef
extends Resource
## What the rival does on one turn, shown over its head (GDD §4.6).

enum StatusTarget { PLAYER, SELF }

@export var label := ""
## -1 = no attack.
@export var attack := -1
@export var block := 0
## "none" = no status.
@export_enum("none", "spicy", "flustered", "rattled", "burnt", "focus", "inspired") var status := "none"
@export var status_amount := 0
## PLAYER = debuff on Apis (Taunt), SELF = buff on the rival.
@export var status_target: StatusTarget = StatusTarget.PLAYER


func has_attack() -> bool:
	return attack >= 0


func has_status() -> bool:
	return status != "" and status != "none"
