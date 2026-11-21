class_name Stage
extends Node3D
## Graybox cooking-show diorama. Everything static lives in stage.tscn (move it in the editor);
## this script only does the moving parts: Plate contents, flinch, idle bob, crowd.

## Placeholder ingredient colors on the Plate, by tag.
const TAG_COLORS := {
	PROTEIN = Color("#f6d36b"),
	CARB = Color("#d9a35b"),
	VEGGIE = Color("#d8342c"),
	FAT = Color("#fff1a8"),
	DAIRY = Color("#fafafa"),
	SPICE = Color("#b8261f"),
	SAUCE = Color("#8a3b1e"),
}

@export_group("Crowd")
@export var crowd_rows := 2
@export var crowd_per_row := 16
@export var crowd_color := Color("#b5703a")
@export var crowd_origin := Vector3(-11, 0.6, 6.2)

@onready var camera: Camera3D = $Camera3D
@onready var player: Node3D = $Player
@onready var rival: Node3D = $Rival
@onready var plate_items: Node3D = $Plate/Items
## Above the rival's head: intent label. Above Apis: floating numbers. Prep table: board UI.
@onready var rival_intent_anchor: Marker3D = $Rival/IntentAnchor
@onready var player_anchor: Marker3D = $Player/Anchor
@onready var board_anchor: Marker3D = $BoardAnchor

var _time := 0.0
var _hit_at := {player = -10.0, rival = -10.0}
var _base := {}
var _crowd: Array[Node3D] = []


func _ready() -> void:
	_base[player] = player.position
	_base[rival] = rival.position
	_spawn_crowd()


## One block per ingredient on the Plate, colored by its first tag.
func set_plate(tags: Array) -> void:
	for child in plate_items.get_children():
		child.queue_free()
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	mesh.radial_segments = 6
	mesh.rings = 3
	for i in tags.size():
		var m := MeshInstance3D.new()
		m.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TAG_COLORS.get(tags[i], Color("#d8342c"))
		m.material_override = mat
		var a := float(i) / maxi(1, tags.size()) * TAU
		var r := 0.3 if tags.size() > 1 else 0.0
		m.position = Vector3(cos(a) * r, 0.17, sin(a) * r)
		plate_items.add_child(m)


## Flinch a chef when it takes Pressure. who: "player" | "rival"
func hit(who: String) -> void:
	_hit_at[who] = _time


## Screen position of a 3D anchor, for UI that follows the stage.
func screen_pos(anchor: Node3D) -> Vector2:
	return camera.unproject_position(anchor.global_position)


func _process(delta: float) -> void:
	_time += delta
	# Idle bob + sideways flinch shake that decays over ~0.4 s.
	player.position = _base[player] + Vector3(_shake("player"), absf(sin(_time * 2.2)) * 0.06, 0)
	rival.position = _base[rival] + Vector3(_shake("rival"), absf(sin(_time * 2.0 + 1.0)) * 0.06, 0)
	for m in _crowd:
		var phase: float = m.get_meta("phase")
		var base_y: float = m.get_meta("base_y")
		m.position.y = base_y + maxf(0.0, sin(_time * 3.0 + phase)) * 0.12


func _shake(who: String) -> float:
	var dt: float = _time - _hit_at[who]
	return sin(dt * 60.0) * 0.18 * (1.0 - dt / 0.4) if dt < 0.4 else 0.0


func _spawn_crowd() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.2
	mesh.radial_segments = 6
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = crowd_color
	mesh.material = mat
	var holder := Node3D.new()
	holder.name = "Crowd"
	add_child(holder)
	for row in crowd_rows:
		for i in crowd_per_row:
			var m := MeshInstance3D.new()
			m.mesh = mesh
			m.position = crowd_origin + Vector3(i * 1.45 + (row % 2) * 0.7, row * 0.35, row * 1.2)
			m.set_meta("phase", randf() * TAU)
			m.set_meta("base_y", m.position.y)
			holder.add_child(m)
			_crowd.append(m)
