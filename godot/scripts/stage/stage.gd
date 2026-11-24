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
## Height of a full-strength cheer jump (FxCue.crowd = 1).
@export var cheer_height := 0.55
@export var cheer_time := 0.6

@onready var camera: Camera3D = $Camera3D
## Pixel filter post-process quad (assets/shaders/pixel_post.gdshader); main.gd toggles it.
@onready var pixel_post: MeshInstance3D = $Camera3D/PixelPost
## Close-up camera for cutscenes (SignatureCutscene moves it between CutMarkers), with its own
## copy of the pixel filter quad.
@onready var cut_camera: Camera3D = $CutCamera
@onready var cut_pixel_post: MeshInstance3D = $CutCamera/CutPixelPost
@onready var player: Chef = $Player
@onready var rival: Chef = $Rival
@onready var plate_items: Node3D = $Plate/Items
## Above the rival's head: intent label. Above Apis: floating numbers. Prep table: board UI.
@onready var rival_intent_anchor: Marker3D = $Rival/IntentAnchor
@onready var player_anchor: Marker3D = $Player/Anchor
@onready var board_anchor: Marker3D = $BoardAnchor
## Top of the rival's counter: its face-down stations sit here (GRAND_DESIGN §3.5).
@onready var rival_stations_anchor: Marker3D = $RivalCounter/RivalStationsAnchor

var _time := 0.0
var _hit_at := {player = -10.0, rival = -10.0}
var _act_at := {player = -10.0, rival = -10.0}
var _base := {}
var _crowd: Array[Node3D] = []
## Lost duel (FinishCutscene): the crowd stops bobbing until the next duel.
var crowd_still := false
var _cheer_at := -10.0
var _cheer := 0.0


func _ready() -> void:
	_base[player] = player.position
	_base[rival] = rival.position
	_spawn_crowd()
	_flatten_all(self)
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


## On narrow windows (e.g. 1024x640) widen the FOV so the whole stage stays visible.
func _fit_camera() -> void:
	var s := get_viewport().get_visible_rect().size
	var aspect := s.x / maxf(1.0, s.y)
	camera.fov = 30.0 * pow(1.7 / aspect, 0.8) if aspect < 1.7 else 30.0


## Flat-shaded look (one solid color per face, like the Three.js `flatShading`): rebuild
## every primitive mesh with per-face normals and matte, non-specular materials.
func _flatten_all(node: Node) -> void:
	for child in node.get_children():
		_flatten_all(child)
	var mi := node as MeshInstance3D
	if mi and mi.mesh is PrimitiveMesh and not mi.material_override is ShaderMaterial:
		mi.mesh = flat_mesh(mi.mesh)
		if mi.material_override is StandardMaterial3D:
			_matte(mi.material_override)


static var _flat_cache := {}


static func flat_mesh(mesh: PrimitiveMesh) -> ArrayMesh:
	if _flat_cache.has(mesh):
		return _flat_cache[mesh]
	var arr := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	for i in range(0, idx.size(), 3):
		var a := verts[idx[i]]
		var b := verts[idx[i + 1]]
		var c := verts[idx[i + 2]]
		var n := (b - a).cross(c - a).normalized()
		var ref := normals[idx[i]] + normals[idx[i + 1]] + normals[idx[i + 2]]
		if n.dot(ref) < 0.0:
			n = -n
		for v in [a, b, c]:
			out_v.append(v)
			out_n.append(n)
	var surf := []
	surf.resize(Mesh.ARRAY_MAX)
	surf[Mesh.ARRAY_VERTEX] = out_v
	surf[Mesh.ARRAY_NORMAL] = out_n
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf)
	if mesh.material:
		var m: Material = mesh.material
		if m is StandardMaterial3D:
			m = m.duplicate()
			_matte(m)
		am.surface_set_material(0, m)
	_flat_cache[mesh] = am
	return am


static func _matte(m: StandardMaterial3D) -> void:
	m.roughness = 1.0
	m.metallic_specular = 0.0


## One block per ingredient on the Plate, colored by its first tag.
func set_plate(tags: Array) -> void:
	for child in plate_items.get_children():
		child.queue_free()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	sphere.radial_segments = 6
	sphere.rings = 3
	var mesh := flat_mesh(sphere)
	for i in tags.size():
		var m := MeshInstance3D.new()
		m.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = TAG_COLORS.get(tags[i], Color("#d8342c"))
		_matte(mat)
		m.material_override = mat
		var a := float(i) / maxi(1, tags.size()) * TAU
		var r := 0.3 if tags.size() > 1 else 0.0
		m.position = Vector3(cos(a) * r, 0.17, sin(a) * r)
		plate_items.add_child(m)


## Flinch a chef when it takes Pressure. who: "player" | "rival"
func hit(who: String) -> void:
	_hit_at[who] = _time


## Hop a chef when it takes an action on its turn (rival steps, GRAND_DESIGN §1.3).
func act(who: String) -> void:
	_act_at[who] = _time


## The whole crowd jumps together (FxDirector, on big moments). power 0..1.
func cheer(power: float) -> void:
	if power <= 0.0:
		return
	_cheer = maxf(power, _cheer if _time - _cheer_at < cheer_time else 0.0)
	_cheer_at = _time


## The chef for a duel side: "player" → Apis, anything else ("enemy") → the rival.
func chef(side: String) -> Chef:
	return player if side == "player" else rival


## Screen position of a 3D anchor, for UI that follows the stage.
func screen_pos(anchor: Node3D) -> Vector2:
	return camera.unproject_position(anchor.global_position)


func _process(delta: float) -> void:
	_time += delta
	# Sideways flinch shake that decays over ~0.4 s. Placeholder chefs also bob and hop;
	# chefs with a model get that from their clips (Chef: idle, chop, busy).
	player.position = _base[player] + Vector3(_shake("player"), _bob(player, 2.2, 0.0) + _hop("player"), 0)
	rival.position = _base[rival] + Vector3(_shake("rival"), _bob(rival, 2.0, 1.0) + _hop("rival"), 0)
	for m in _crowd:
		var phase: float = m.get_meta("phase")
		var base_y: float = m.get_meta("base_y")
		var dt := _time - _cheer_at - fmod(phase, 0.5) * 0.12
		var jump := sin(dt / cheer_time * PI) * cheer_height * _cheer if dt > 0.0 and dt < cheer_time else 0.0
		var bob := 0.0 if crowd_still else maxf(0.0, sin(_time * 3.0 + phase)) * 0.12
		m.position.y = base_y + bob + jump


func _shake(who: String) -> float:
	var dt: float = _time - _hit_at[who]
	return sin(dt * 60.0) * 0.18 * (1.0 - dt / 0.4) if dt < 0.4 else 0.0


func _bob(c: Chef, speed: float, phase: float) -> float:
	return 0.0 if c.has_model() else absf(sin(_time * speed + phase)) * 0.06


## Quick 0.3 s hop up and back down (placeholder chefs only).
func _hop(who: String) -> float:
	if chef(who).has_model():
		return 0.0
	var dt: float = _time - _act_at[who]
	return sin(dt / 0.3 * PI) * 0.22 if dt < 0.3 else 0.0


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
