class_name EmoteBubble
extends Control
## Rival emote in a speech bubble beside its head (ART_DIRECTION §5).
## Faces are drawn in code (eyes + mouth only, like the references), so no sprite is needed
## until the pixel assets exist. Call pop(kind); DuelUI decides when.

## Higher wins when two emotes want the bubble at once.
const PRIORITY := {sad = 5, shocked = 4, angry = 3, smug = 2, confident = 1}
const HOLD := 1.5
## Face drawing grid (units), scaled into the bubble.
const GRID := Vector2(40, 26)

var kind := ""
## Angry stays as a small bubble while the rival is nearly beaten.
var sticky := false
var _tw: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(Pal.em(4.6), Pal.em(3.4))
	size = custom_minimum_size
	pivot_offset = Vector2(0, size.y)
	hide()


## Show an emote. Returns false when a higher-priority one is on screen.
func pop(kind_: String, keep := false) -> bool:
	if visible and kind != "" and not sticky and PRIORITY.get(kind_, 0) < PRIORITY.get(kind, 0):
		return false
	kind = kind_
	sticky = false
	queue_redraw()
	show()
	if _tw and _tw.is_valid():
		_tw.kill()
	# DuelUI moves the parent with the rival's head; the bubble animates locally.
	position = Vector2.ZERO
	scale = Vector2.ONE * 0.2
	modulate.a = 1.0
	rotation_degrees = 0.0
	_tw = create_tween()
	_tw.tween_property(self, "scale", Vector2.ONE * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "scale", Vector2.ONE, 0.08)
	match kind:
		"smug":  # bounce twice, laughing
			for _i in 2:
				_tw.tween_property(self, "position:y", position.y - Pal.em(0.5), 0.12)
				_tw.tween_property(self, "position:y", position.y, 0.12)
		"angry", "shocked":  # shake
			for i in 6:
				_tw.tween_property(self, "rotation_degrees", 7.0 if i % 2 == 0 else -7.0, 0.05)
			_tw.tween_property(self, "rotation_degrees", 0.0, 0.05)
	if keep:
		_tw.tween_interval(HOLD)
		_tw.tween_property(self, "scale", Vector2.ONE * 0.6, 0.2)
		_tw.tween_callback(func() -> void: sticky = true)
		return true
	_tw.tween_interval(HOLD)
	if kind == "sad":  # sink slowly
		_tw.tween_property(self, "position:y", position.y + Pal.em(0.8), 0.6)
		_tw.parallel().tween_property(self, "modulate:a", 0.0, 0.6)
	else:
		_tw.tween_property(self, "modulate:a", 0.0, 0.2)
	_tw.tween_callback(_done)
	return true


func clear() -> void:
	if _tw and _tw.is_valid():
		_tw.kill()
	kind = ""
	sticky = false
	hide()


func _done() -> void:
	kind = ""
	hide()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var b := Pal.em(0.22)
	var edge := Pal.RED if kind == "angry" else (Pal.BLUE if kind == "sad" else Pal.INK)
	# Hard shadow, border, fill (pixel-style: square corners).
	draw_rect(Rect2(r.position + Vector2(b, b), r.size), Pal.INK)
	draw_rect(r, edge)
	draw_rect(r.grow(-b), Pal.CREAM)
	# Tail toward the head (bottom-left).
	var t := PackedVector2Array([Vector2(b * 2, size.y - b), Vector2(b * 7, size.y - b), Vector2(-b * 2, size.y + b * 5)])
	draw_colored_polygon(t, edge)
	var ti := PackedVector2Array([Vector2(b * 3, size.y - b * 1.5), Vector2(b * 6, size.y - b * 1.5), Vector2(b * 0.5, size.y + b * 2.5)])
	draw_colored_polygon(ti, Pal.CREAM)
	_face()


## Grid point → bubble pixels (face area inset from the border).
func _p(x: float, y: float) -> Vector2:
	var inset := Vector2(Pal.em(0.55), Pal.em(0.5))
	var area := size - inset * 2.0
	return inset + Vector2(x / GRID.x * area.x, y / GRID.y * area.y)


func _line(pts: Array, w := 3.2) -> void:
	var out := PackedVector2Array()
	for q: Vector2 in pts:
		out.append(_p(q.x, q.y))
	draw_polyline(out, Pal.INK, Pal.em(w / 10.0) * 1.2)


func _box(x: float, y: float, w: float, h: float, c := Pal.INK) -> void:
	var a := _p(x, y)
	draw_rect(Rect2(a, _p(x + w, y + h) - a), c)


func _face() -> void:
	match kind:
		"smug":
			_line([Vector2(5, 11), Vector2(10, 5), Vector2(15, 11)])
			_line([Vector2(25, 11), Vector2(30, 5), Vector2(35, 11)])
			var m := PackedVector2Array([_p(11, 15), _p(29, 15), _p(25, 23), _p(15, 23)])
			draw_colored_polygon(m, Pal.INK)
		"angry":
			_line([Vector2(3, 3), Vector2(15, 8)])
			_line([Vector2(37, 3), Vector2(25, 8)])
			_box(6, 10, 7, 6)
			_box(27, 10, 7, 6)
			_line([Vector2(10, 23), Vector2(14, 19), Vector2(18, 23), Vector2(22, 19), Vector2(26, 23), Vector2(30, 19)])
		"sad":
			_line([Vector2(4, 6), Vector2(16, 6)])
			_line([Vector2(10, 6), Vector2(10, 16)])
			_line([Vector2(24, 6), Vector2(36, 6)])
			_line([Vector2(30, 6), Vector2(30, 16)])
			_line([Vector2(14, 24), Vector2(20, 19), Vector2(26, 24)])
			_box(32, 17, 3, 6, Pal.BLUE)
		"shocked":
			draw_arc(_p(10, 9), Pal.em(0.45), 0.0, TAU, 12, Pal.INK, Pal.em(0.3))
			draw_arc(_p(30, 9), Pal.em(0.45), 0.0, TAU, 12, Pal.INK, Pal.em(0.3))
			_box(16, 16, 8, 8)
		"confident":
			_line([Vector2(5, 5), Vector2(14, 10), Vector2(5, 15)])
			_box(26, 5, 8, 9)
			_line([Vector2(11, 19), Vector2(20, 23), Vector2(29, 19)])
