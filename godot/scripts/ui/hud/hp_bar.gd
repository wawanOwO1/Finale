@tool
class_name HpBar
extends Control
## Confidence bar (HUD v2): ink frame, dark track, flat fill with a light top edge, a blue
## Composure cap on the right when shield > 0, and "now/max" text in the middle.

@export_range(0.0, 1.0) var ratio := 1.0:
	set(v):
		ratio = clampf(v, 0.0, 1.0)
		queue_redraw()
@export var shield := 0:
	set(v):
		shield = maxi(0, v)
		queue_redraw()
@export var text := "60/60":
	set(v):
		text = v
		queue_redraw()
@export var fill_color := Color("#d8342c")
@export var shield_color := Color("#3f7fae")
@export var track_color := Color("#120c09")
@export var frame_color := Color("#1a120d")
@export var inner_line := Color("#3b2c22")
@export var border := 4.0
@export var font_size := 24
@export var text_color := Color("#fbf3e2")
## Crack overlay after a big hit (FX_MASTERPLAN.md §3.2): 0 = none, 1 = fully drawn. FxDirector
## sets it to 1 and fades it out. crack_seed picks where the cracks run.
@export_range(0.0, 1.0) var crack := 0.0:
	set(v):
		crack = clampf(v, 0.0, 1.0)
		queue_redraw()
var crack_seed := 0


func _draw() -> void:
	var b := border
	draw_rect(Rect2(Vector2.ZERO, size), frame_color)
	var inner := Rect2(Vector2.ONE * b, size - Vector2.ONE * b * 2.0)
	draw_rect(inner, track_color)
	draw_rect(inner, inner_line, false, 2.0)
	var font := get_theme_default_font()
	var cap_w := 0.0
	if shield > 0:
		cap_w = maxf(size.y * 1.1, font.get_string_size(str(shield), HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(font_size * 0.8)).x + 14.0)
	var w := (inner.size.x - cap_w) * ratio
	if w > 0.0:
		var f := Rect2(inner.position + Vector2(2, 2), Vector2(maxf(0.0, w - 4.0), inner.size.y - 4.0))
		draw_rect(f, fill_color)
		draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.25)), fill_color.lightened(0.25))
		draw_rect(Rect2(f.position + Vector2(0, f.size.y * 0.78), Vector2(f.size.x, f.size.y * 0.22)), fill_color.darkened(0.25))
	if cap_w > 0.0:
		var c := Rect2(Vector2(inner.end.x - cap_w, inner.position.y), Vector2(cap_w, inner.size.y))
		draw_rect(c, shield_color)
		draw_rect(Rect2(c.position, Vector2(c.size.x, c.size.y * 0.25)), shield_color.lightened(0.3))
		draw_rect(Rect2(c.position, Vector2(b * 0.75, c.size.y)), frame_color)
		_text(c, str(shield), roundi(font_size * 0.8))
	if crack > 0.0:
		_cracks(inner)
	_text(Rect2(inner.position, Vector2(inner.size.x - cap_w, inner.size.y)), text, font_size)


## Two jagged ink lines top to bottom, with a light edge, on a 2 px step so they read as pixel art.
func _cracks(r: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = crack_seed
	var ink := Color(frame_color, crack)
	var light := Color(fill_color.lightened(0.5), crack * 0.8)
	for n in 2:
		var x := r.position.x + r.size.x * rng.randf_range(0.2 + n * 0.4, 0.4 + n * 0.4)
		var pts := PackedVector2Array()
		var steps := 4
		for i in steps + 1:
			var y := r.position.y + r.size.y * i / steps
			pts.append(Vector2(snappedf(x + rng.randf_range(-9.0, 9.0), 2.0), snappedf(y, 2.0)))
		draw_polyline(pts, light, 2.0)
		for i in pts.size():
			pts[i] += Vector2(2, 0)
		draw_polyline(pts, ink, 3.0)


func _text(r: Rect2, s: String, fs: int) -> void:
	var font := get_theme_default_font()
	var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(r.position.x + (r.size.x - tw) / 2.0, r.position.y + r.size.y / 2.0 + (font.get_ascent(fs) - font.get_descent(fs)) / 2.0)
	draw_string(font, p + Vector2(2, 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, frame_color)
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_color)
