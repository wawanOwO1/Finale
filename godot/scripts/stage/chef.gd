@tool
class_name Chef
extends Node3D
## A chef on the stage. Character models are child nodes named by character id ("apis", "tony"):
## GLB instances with an AnimationPlayer holding the clips from ANIMATION_DESIGN.md
## (idle, chop, busy, victory, lose). `character` picks the one that shows; with no matching
## model the Placeholder (capsule body + oversized head + hat, GDD §7.1) shows instead.

## Id of the child model to show (EnemyDef.id for rivals). Unknown id → Placeholder.
@export var character := "":
	set(value):
		character = value
		_apply_character()

## Placeholder body color (only used while no model is shown).
@export var body_color := Color("#2f6f8f"):
	set(value):
		body_color = value
		_apply_color()

@export_group("Animation")
## Cross-fade between clips, in seconds.
@export_range(0.0, 1.0, 0.01) var blend_time := 0.15
## Looping clip the chef returns to after a one-shot.
@export var idle_clip := "idle"

var _anim: AnimationPlayer
## Bumped by every play request, so an older one-shot does not send the chef back to idle.
var _token := 0
## victory / lose: the duel is over, nothing else may play until reset().
var _final := false


func _ready() -> void:
	_apply_color()
	_apply_character()


func has_model() -> bool:
	return _anim != null


## Clip playing now ("" without a model).
func current_clip() -> String:
	return _anim.current_animation if _anim else ""


## Back to idle (new duel).
func reset() -> void:
	_final = false
	_token += 1
	_play(idle_clip)


## Play `clip` once (one full cycle, or `seconds` if given), then return to idle.
func perform(clip: String, seconds := -1.0) -> void:
	if _anim == null or _final or not _anim.has_animation(clip):
		return
	_token += 1
	var token := _token
	_play(clip)
	var length := seconds if seconds > 0.0 else _anim.get_animation(clip).length
	await get_tree().create_timer(length).timeout
	if token == _token and not _final:
		_play(idle_clip)


## End-of-duel clip (victory / lose). It holds its last frame until reset().
func finish(clip: String) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_final = true
	_token += 1
	_play(clip)


func _play(clip: String) -> void:
	if _anim and _anim.has_animation(clip):
		_anim.play(clip, blend_time)


func _apply_character() -> void:
	if not is_node_ready():
		return
	_anim = null
	for child in get_children():
		var players := child.find_children("*", "AnimationPlayer", true, false)
		if players.is_empty():
			continue
		var on := String(child.name) == character
		child.visible = on
		if on:
			_anim = players[0]
	var placeholder := get_node_or_null("Placeholder") as Node3D
	if placeholder:
		placeholder.visible = _anim == null
	if _anim and not Engine.is_editor_hint():
		reset()


func _apply_color() -> void:
	var body := get_node_or_null("Placeholder/Body") as MeshInstance3D
	if body == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	body.material_override = mat
