@tool
class_name HudPanel
extends PanelContainer
## Dark HUD panel from the canvas board "HUD v2" (ART_DIRECTION §4): ink border + hard shadow come
## from the panel StyleBox in the scene; this adds the lighter inner line and the optional tab label
## that sits on the top edge ("STATIONS", "PLAYER").

@export var tab_text := "":
	set(v):
		tab_text = v
		queue_redraw()
## Left edge of the tab, in px from the panel's left edge.
@export var tab_x := 90.0:
	set(v):
		tab_x = v
		queue_redraw()
@export var tab_height := 46.0
@export var tab_font_size := 24
@export var inner_line := Color("#5c4231")
@export var inner_width := 3.0
@export var text_color := Color("#fbf3e2")


func _draw() -> void:
	var sb := get_theme_stylebox("panel") as StyleBoxFlat
	var b := float(sb.border_width_left) if sb else 6.0
	var ink := sb.border_color if sb else Color("#1a120d")
	var bg := sb.bg_color if sb else Color("#2e221b")
	# Inner light line just inside the ink border.
	var r := Rect2(Vector2.ONE * b, size - Vector2.ONE * b * 2.0)
	draw_rect(r.grow(-inner_width / 2.0), inner_line, false, inner_width)
	if tab_text == "":
		return
	var font := get_theme_default_font()
	var tw := font.get_string_size(tab_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_font_size).x
	var tab := Rect2(tab_x, -tab_height, tw + tab_font_size * 2.0, tab_height + b)
	draw_rect(tab, ink)
	draw_rect(Rect2(tab.position + Vector2(b, b), tab.size - Vector2(b * 2.0, b)), bg)
	draw_line(tab.position + Vector2(b + inner_width / 2.0, b + inner_width), Vector2(tab.end.x - b - inner_width / 2.0, tab.position.y + b + inner_width), inner_line, inner_width)
	var base := tab.position.y + b + (tab_height - b) / 2.0 + font.get_ascent(tab_font_size) / 2.0 - font.get_descent(tab_font_size) / 2.0
	draw_string(font, Vector2(tab.position.x + tab_font_size, base), tab_text, HORIZONTAL_ALIGNMENT_LEFT, -1, tab_font_size, text_color)
