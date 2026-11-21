@tool
class_name Chef
extends Node3D
## Placeholder chef: capsule body + oversized head + hat (GDD §7.1).
## Swap the child meshes for a real model later; keep the node name "Body" or update this script.

@export var body_color := Color("#2f6f8f"):
	set(value):
		body_color = value
		_apply_color()


func _ready() -> void:
	_apply_color()


func _apply_color() -> void:
	var body := get_node_or_null("Body") as MeshInstance3D
	if body == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	body.material_override = mat
