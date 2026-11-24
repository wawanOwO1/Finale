class_name VsIntro
extends Control
## VS screen before the 3 · 2 · 1 (FX_MASTERPLAN.md §6.4): a diagonal split, Apis on the left, the
## rival on the right, a slammed "VS" and dash lines. All 2D: the portraits are pictures rendered once
## from the models (tests/portrait_render.gd), so this costs no extra 3D pass on the web.
## The %VsIntro node in duel_ui.tscn; DuelUI awaits play() in its intro. Click to skip.

signal done

@export var enabled := true
@export var player_id := "apis"
@export var player_name := "APIS"
@export var player_title := "The Challenger"
## Character id → portrait (assets/portraits/<id>.png). A rival without one shows its name only.
@export var portraits: Dictionary = {}
@export var left_color := Color("#2f6f8f")
@export var right_color := Color("#a8231d")
@export var seam_color := Color("#1a120d")
@export_group("Timing (seconds)")
@export var slide_in := 0.28
@export var hold := 1.25
@export var slide_out := 0.22

@onready var _left: Control = $Left
@onready var _right: Control = $Right
@onready var _left_bg: Polygon2D = $Left/Bg
@onready var _right_bg: Polygon2D = $Right/Bg
@onready var _seam: Polygon2D = $Seam
@onready var _left_pic: TextureRect = $Left/Portrait
@onready var _right_pic: TextureRect = $Right/Portrait
@onready var _left_name: Label = $Left/Name
@onready var _right_name: Label = $Right/Name
@onready var _left_title: Label = $Left/Title
@onready var _right_title: Label = $Right/Title
@onready var _vs: Label = $Vs
@onready var _lines: ColorRect = $Lines

var playing := false
var _tw: Tween
var _skip := false


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_STOP


## Show Apis vs `rival` (EnemyDef) and wait until it is gone (or skipped).
func play(rival: EnemyDef) -> void:
	if not enabled or rival == null:
		return
	playing = true
	_skip = false
	_fill(_left_pic, _left_name, _left_title, player_id, player_name, player_title)
	_fill(_right_pic, _right_name, _right_title, rival.id, rival.name.to_upper(), rival.title)
	_layout()
	var w := size.x
	_left.position.x = -w
	_right.position.x = w
	_vs.scale = Vector2.ONE * 3.0
	_vs.modulate.a = 0.0
	_seam.modulate.a = 0.0
	_lines.modulate.a = 0.0
	show()
	_tw = create_tween()
	_tw.tween_property(_left, "position:x", 0.0, slide_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_property(_right, "position:x", 0.0, slide_in).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.parallel().tween_property(_lines, "modulate:a", 1.0, slide_in)
	_tw.tween_property(_seam, "modulate:a", 1.0, 0.05)
	_tw.tween_callback(_sfx.bind("turn"))
	_tw.parallel().tween_property(_vs, "modulate:a", 1.0, 0.06)
	_tw.parallel().tween_property(_vs, "scale", Vector2.ONE * 0.9, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tw.tween_property(_vs, "scale", Vector2.ONE, 0.08)
	_tw.tween_interval(hold)
	_tw.tween_callback(_out)
	await done


func _process(_delta: float) -> void:
	if playing:
		(_lines.material as ShaderMaterial).set_shader_parameter("seed", Time.get_ticks_msec() / 1000.0 * 2.5)


## Click: straight to the slide-out.
func _gui_input(event: InputEvent) -> void:
	if playing and not _skip and event is InputEventMouseButton and event.pressed:
		accept_event()
		_out()


func _out() -> void:
	if _skip:
		return
	_skip = true
	if _tw and _tw.is_valid():
		_tw.kill()
	var w := size.x
	_tw = create_tween().set_parallel()
	_tw.tween_property(_left, "position:x", -w, slide_out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_property(_right, "position:x", w, slide_out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tw.tween_property(_vs, "modulate:a", 0.0, slide_out)
	_tw.tween_property(_seam, "modulate:a", 0.0, slide_out)
	_tw.tween_property(_lines, "modulate:a", 0.0, slide_out)
	_tw.chain().tween_callback(func() -> void:
		hide()
		playing = false
		done.emit())


func _fill(pic: TextureRect, name_l: Label, title_l: Label, id: String, n: String, title: String) -> void:
	var tex: Texture2D = portraits.get(id)
	pic.texture = tex
	pic.visible = tex != null
	name_l.text = n
	title_l.text = title


## Diagonal split sized to the screen: the seam leans like the cut-in bar.
func _layout() -> void:
	var w := size.x
	var h := size.y
	var top := w * 0.56
	var bottom := w * 0.44
	var t := 10.0
	_left_bg.polygon = PackedVector2Array([Vector2(0, 0), Vector2(top, 0), Vector2(bottom, h), Vector2(0, h)])
	_right_bg.polygon = PackedVector2Array([Vector2(top, 0), Vector2(w, 0), Vector2(w, h), Vector2(bottom, h)])
	_seam.polygon = PackedVector2Array([Vector2(top - t, 0), Vector2(top + t, 0), Vector2(bottom + t, h), Vector2(bottom - t, h)])
	_left_bg.color = left_color
	_right_bg.color = right_color
	_seam.color = seam_color
	var ph := h * 0.82
	var pw := ph * 360.0 / 420.0
	_left_pic.size = Vector2(pw, ph)
	_left_pic.position = Vector2(w * 0.04, h - ph)
	_right_pic.size = Vector2(pw, ph)
	_right_pic.position = Vector2(w * 0.96 - pw, h - ph)
	for l: Label in [_left_name, _left_title, _right_name, _right_title]:
		l.reset_size()
	# Title right under the name (labels carry some empty space under the glyphs).
	var title_y := h * 0.06 + _left_name.size.y * 0.82
	_left_name.position = Vector2(w * 0.05, h * 0.06)
	_left_title.position = Vector2(w * 0.05 + Pal.em(0.4), title_y)
	_right_name.position = Vector2(w * 0.95 - _right_name.size.x, h * 0.06)
	_right_title.position = Vector2(w * 0.95 - _right_title.size.x - Pal.em(0.4), title_y)
	_vs.reset_size()
	_vs.pivot_offset = _vs.size / 2.0
	_vs.position = Vector2(w * 0.5, h * 0.5) - _vs.size / 2.0
	(_lines.material as ShaderMaterial).set_shader_parameter("rect_px", size)


## Through the Audio autoload, looked up at run time (scripts run with --script load before it).
func _sfx(key: String) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.sfx(key)
