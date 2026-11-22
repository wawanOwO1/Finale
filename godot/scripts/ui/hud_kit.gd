class_name HudKit
## Pixel-style HUD pieces from the canvas "HUD Kit" board (ART_DIRECTION §4.1):
## skewed Confidence bar with a white tip, segmented Hype bar, diamond badge, chips, square boxes.
## All drawn in code so they scale with Pal.EM until the pixel art replaces them.


## Square box: ink border, hard offset shadow down-right (pixel look, no rounding).
static func box(bg: Color, border := Pal.INK, border_em := 0.18, shadow_em := 0.25) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(maxi(2, roundi(Pal.em(border_em))))
	s.set_corner_radius_all(2)
	if shadow_em > 0.0:
		s.shadow_color = Pal.INK
		s.shadow_size = 1
		s.shadow_offset = Vector2.ONE * Pal.em(shadow_em)
	return s


## Two-part chip like "ROUND | 2": cream label, ink value.
static func chip(label_text: String, value_text: String, value_color := Pal.GOLD, size_em := 1.0) -> HBoxContainer:
	var row := Ui.hbox(0.0)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var a := Ui.panel(Ui.pad(box(Pal.CREAM, Pal.INK, 0.16, 0.0), 0.55 * size_em, 0.1), Ui.label(label_text, 0.75 * size_em, Pal.INK))
	var vl := Ui.label(value_text, 1.15 * size_em, value_color)
	vl.name = "Value"
	var b := Ui.panel(Ui.pad(box(Pal.INK, Pal.INK, 0.16, 0.0), 0.55 * size_em, 0.0), vl)
	row.add_child(a)
	row.add_child(b)
	return row


## Small status-like chip: colored fill, cream text.
static func tag(text: String, bg: Color, fg := Pal.CREAM, size_em := 0.7) -> PanelContainer:
	return Ui.panel(Ui.pad(box(bg, Pal.INK, 0.12, 0.0), 0.35, 0.05), Ui.label(text, size_em, fg))


## Confidence bar (ref 3, "skewed" bar): ink frame, red fill, white tip, optional blue
## Composure stripe on top. Text sits in an upright Label child named "Text".
class SkewBar extends Control:
	var ratio := 1.0:
		set(v):
			ratio = clampf(v, 0.0, 1.0)
			queue_redraw()
	## 0..1 of the width shown as a Composure stripe.
	var stripe := 0.0:
		set(v):
			stripe = clampf(v, 0.0, 1.0)
			queue_redraw()
	var fill_color := Pal.RED
	var skew_px := 0.0
	var text_label: Label

	func _init(w_em: float, h_em: float, text_em := 0.9) -> void:
		custom_minimum_size = Vector2(Pal.em(w_em), Pal.em(h_em))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		skew_px = Pal.em(h_em) * 0.28
		text_label = Ui.outlined("", text_em, Color.WHITE, 0.12)
		text_label.name = "Text"
		Ui.fill(text_label)
		add_child(text_label)

	func _quad(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
		# Parallelogram leaning right: bottom edge shifted left by skew_px.
		var k := skew_px / maxf(1.0, size.y)
		return PackedVector2Array([Vector2(x0 + (size.y - y0) * k, y0), Vector2(x1 + (size.y - y0) * k, y0),
				Vector2(x1 + (size.y - y1) * k, y1), Vector2(x0 + (size.y - y1) * k, y1)])

	func _draw() -> void:
		var b := maxf(2.0, Pal.em(0.18))
		var w := size.x - skew_px
		draw_colored_polygon(_quad(Pal.em(0.25), w + Pal.em(0.25), Pal.em(0.25), size.y + Pal.em(0.25)), Pal.INK)
		draw_colored_polygon(_quad(0, w, 0, size.y), Pal.INK)
		var inner_w := w - b * 2.0
		if ratio > 0.0:
			draw_colored_polygon(_quad(b, b + inner_w * ratio, b, size.y - b), fill_color)
			var tip := maxf(b, Pal.em(0.3))
			var tx := b + inner_w * ratio
			draw_colored_polygon(_quad(maxf(b, tx - tip), tx, b, size.y - b), Color.WHITE)
		if stripe > 0.0:
			draw_colored_polygon(_quad(b, b + inner_w * stripe, b, b + (size.y - 2.0 * b) * 0.3), Pal.BLUE)


## Hype bar (ref 3 #13): N square segments on an ink strip. Full = purple frame, last segment white.
class SegmentBar extends Control:
	var segments := 10
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()
	var max_value := 100.0
	var full := false:
		set(v):
			full = v
			queue_redraw()

	func _init(w_em: float, h_em: float) -> void:
		custom_minimum_size = Vector2(Pal.em(w_em), Pal.em(h_em))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func _draw() -> void:
		var pad := maxf(2.0, Pal.em(0.22))
		var gap := maxf(2.0, Pal.em(0.15))
		draw_rect(Rect2(Vector2.ONE * Pal.em(0.2), size), Color.BLACK)
		draw_rect(Rect2(Vector2.ZERO, size), Pal.PURPLE if full else Pal.INK)
		var seg_w := (size.x - pad * 2.0 - gap * (segments - 1)) / segments
		var per := max_value / segments
		for i in segments:
			var r := Rect2(pad + i * (seg_w + gap), pad, seg_w, size.y - pad * 2.0)
			var amount := clampf((value - i * per) / per, 0.0, 1.0)
			draw_rect(r, Pal.INK_SOFT.darkened(0.25))
			if amount > 0.0:
				var c := Pal.GOLD
				if full and i == segments - 1:
					c = Color.WHITE
				elif amount < 1.0:
					c = Pal.ORANGE
				draw_rect(Rect2(r.position, Vector2(r.size.x * amount, r.size.y)), c)


## Diamond badge (portrait, intent): rotated square with ink border and hard shadow.
## Children are laid out centered and stay upright.
class Diamond extends Container:
	var fill := Pal.CREAM:
		set(v):
			fill = v
			queue_redraw()
	## 0..1 of the lower half shaded (two-turn intents half done).
	var half := false:
		set(v):
			half = v
			queue_redraw()
	var lower := Pal.INK_SOFT

	func _init(size_em: float, fill_ := Pal.CREAM) -> void:
		custom_minimum_size = Vector2.ONE * Pal.em(size_em)
		fill = fill_
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			for c in get_children():
				var ctl := c as Control
				if ctl:
					var ms := ctl.get_combined_minimum_size()
					fit_child_in_rect(ctl, Rect2((size - ms) / 2.0, ms))

	func _pts(inset: float, off := Vector2.ZERO) -> PackedVector2Array:
		var c := size / 2.0 + off
		var r := size.x / 2.0 - inset
		return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

	func _draw() -> void:
		var b := maxf(2.0, Pal.em(0.2))
		draw_colored_polygon(_pts(0.0, Vector2.ONE * Pal.em(0.25)), Pal.INK)
		draw_colored_polygon(_pts(0.0), Pal.INK)
		draw_colored_polygon(_pts(b * 1.4), fill)
		if half:
			var p := _pts(b * 1.4)
			draw_colored_polygon(PackedVector2Array([p[1], p[2], p[3]]), lower)
