@tool
class_name DiamondBadge
extends Container
## Diamond badge (player portrait, rival intent): rotated square with an ink border, a light
## inner ring and a hard shadow. Children are centered and stay upright.

@export var fill := Color("#fbf3e2"):
	set(v):
		fill = v
		queue_redraw()
@export var ring := Color("#e3cfae"):
	set(v):
		ring = v
		queue_redraw()
@export var ink := Color("#1a120d")
@export var border := 7.0
@export var shadow := Vector2(6, 6)
@export var shadow_color := Color(0.12, 0.08, 0.06, 0.45)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		for c in get_children():
			var ctl := c as Control
			if ctl:
				var ms := ctl.get_combined_minimum_size()
				fit_child_in_rect(ctl, Rect2((size - ms) / 2.0, ms))


func _pts(inset: float, off := Vector2.ZERO) -> PackedVector2Array:
	var c := size / 2.0 + off
	var r := minf(size.x, size.y) / 2.0 - inset
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])


func _draw() -> void:
	draw_colored_polygon(_pts(0.0, shadow), shadow_color)
	draw_colored_polygon(_pts(0.0), ink)
	draw_colored_polygon(_pts(border * 1.4), ring)
	draw_colored_polygon(_pts(border * 1.4 + 6.0), fill)
