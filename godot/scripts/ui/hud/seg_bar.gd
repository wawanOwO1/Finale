@tool
class_name SegBar
extends Control
## Segmented gauge (Hype in the top bar, stats on cards): N squares on an ink strip.
## Full = last segment white and the frame turns purple.

@export var segments := 10:
	set(v):
		segments = maxi(1, v)
		queue_redraw()
@export var max_value := 100.0
@export var value := 0.0:
	set(v):
		value = v
		queue_redraw()
@export var full := false:
	set(v):
		full = v
		queue_redraw()
@export var fill_color := Color("#f2b632")
@export var partial_color := Color("#e07b28")
@export var empty_color := Color("#4a382c")
@export var frame_color := Color("#1a120d")
@export var full_frame_color := Color("#8a3fb0")
@export var pad := 4.0
@export var gap := 4.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), full_frame_color if full else frame_color)
	var seg_w := (size.x - pad * 2.0 - gap * (segments - 1)) / segments
	var per := max_value / segments
	var h := size.y - pad * 2.0
	for i in segments:
		var r := Rect2(pad + i * (seg_w + gap), pad, seg_w, h)
		draw_rect(r, empty_color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, maxf(1.0, h * 0.15))), empty_color.lightened(0.1))
		var amount := clampf((value - i * per) / per, 0.0, 1.0)
		if amount <= 0.0:
			continue
		var c := fill_color if amount >= 1.0 else partial_color
		if full and i == segments - 1:
			c = Color.WHITE
		var f := Rect2(r.position, Vector2(r.size.x * amount, r.size.y))
		draw_rect(f, c)
		draw_rect(Rect2(f.position, Vector2(f.size.x, maxf(1.0, h * 0.2))), c.lightened(0.3))
