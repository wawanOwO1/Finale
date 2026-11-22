class_name EnemyDef
extends Resource
## A rival chef. One .tres per rival in res://data/enemies/.

@export var id := ""
@export var name := ""
@export var title := ""
@export var confidence := 30
## Intents cycle in order (simple pattern AI; gimmicks come later).
@export var pattern: Array[IntentDef] = []
## Grand final / boss duel: Boss appearance sting, and no Battle_Theme (boss theme comes later).
@export var boss := false
