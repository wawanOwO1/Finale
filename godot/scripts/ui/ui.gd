class_name Ui
## Small builders for the HUD so every panel, chip and icon shares one look
## (the GDScript side of the old style.css). Static layout lives in the .tscn files.

const ICON_DIR := "res://assets/icons/%s.svg"

static var _icons := {}
static var _italic: FontVariation


## Flat rounded box with the cartoon "ink" border and a hard drop shadow below.
static func box(bg: Color, border := Pal.INK, border_em := 0.16, radius_em := 0.6, shadow_em := 0.22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(roundi(Pal.em(border_em)))
	s.set_corner_radius_all(roundi(Pal.em(radius_em)))
	if shadow_em > 0.0:
		s.shadow_color = Pal.INK
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, Pal.em(shadow_em) - 1.0)
	s.anti_aliasing = true
	return s


static func pad(s: StyleBox, x_em: float, y_em: float) -> StyleBox:
	s.content_margin_left = Pal.em(x_em)
	s.content_margin_right = Pal.em(x_em)
	s.content_margin_top = Pal.em(y_em)
	s.content_margin_bottom = Pal.em(y_em)
	return s


static func icon_tex(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := ICON_DIR % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]


## A tinted icon (white SVG × color), square, `size_em` wide.
static func icon(name: String, color: Color, size_em := 1.2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_tex(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2.ONE * Pal.em(size_em)
	t.self_modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return t


## Icon with a hard ink drop shadow (CSS drop-shadow(0 Y 0 ink)), for big badges.
static func icon_shadowed(name: String, color: Color, size_em: float, shadow_em := 0.15) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2.ONE * Pal.em(size_em)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow := icon(name, Pal.INK, size_em)
	fill(shadow, Pal.em(shadow_em))
	var top := icon(name, color, size_em)
	top.name = "Icon"
	fill(top)
	holder.add_child(shadow)
	holder.add_child(top)
	return holder


## Stretch a control over its parent (anchors 0..1, zero offsets), optionally shifted down.
## Use this instead of set_anchors_and_offsets_preset() on nodes whose parent has no size yet.
static func fill(c: Control, down := 0.0) -> void:
	c.anchor_left = 0.0
	c.anchor_top = 0.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0.0
	c.offset_right = 0.0
	c.offset_top = down
	c.offset_bottom = down


static func label(text: String, size_em := 1.0, color := Pal.INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", roundi(Pal.em(size_em)))
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## White text with an ink outline (floaters, numbers on badges).
static func outlined(text: String, size_em: float, color := Color.WHITE, outline_em := 0.12) -> Label:
	var l := label(text, size_em, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Pal.INK)
	l.add_theme_constant_override("outline_size", roundi(Pal.em(outline_em)))
	return l


static func rich(bbcode: String, size_em := 1.0, color := Pal.INK, centered := false) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_size_override("normal_font_size", roundi(Pal.em(size_em)))
	r.add_theme_color_override("default_color", color)
	r.text = ("[center]%s[/center]" % bbcode) if centered else bbcode
	return r


static func hbox(sep_em := 0.3) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", roundi(Pal.em(sep_em)))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.alignment = BoxContainer.ALIGNMENT_CENTER
	return b


static func vbox(sep_em := 0.3) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", roundi(Pal.em(sep_em)))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.alignment = BoxContainer.ALIGNMENT_CENTER
	return b


static func panel(style: StyleBox, child: Control = null) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if child:
		p.add_child(child)
	return p


## Status chip: cream tag with the status icon (purple debuff / green buff) + stacks.
static func status_chip(id: String, stacks: int) -> PanelContainer:
	var row := hbox(0.1)
	var color := Pal.PURPLE if StatusDefs.is_debuff(id) else Pal.GREEN
	row.add_child(icon(id, color, 1.2))
	row.add_child(label(str(stacks), 0.8))
	var chip := panel(pad(box(Pal.CREAM, Pal.INK, 0.13, 0.45, 0.0), 0.3, 0.1), row)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	return chip


## Recipe requirement chip (Recipe Book): tag, or key ingredient by name on gold.
static func req_chip(req: String) -> PanelContainer:
	var row := hbox(0.2)
	var tag := req
	var text := req
	var bg := Pal.CREAM
	if req.begins_with("card:"):
		var def := GameDB.card(req.substr(5))
		tag = def.first_tag()
		text = def.name
		bg = Pal.GOLD
	row.add_child(icon(tag, Pal.tag_color(tag), 1.0))
	row.add_child(label(text, 0.8))
	return panel(pad(box(bg, Pal.INK, 0.13, 0.45, 0.0), 0.4, 0.1), row)


## Dark keyword tooltip box (title with icon in gold, text below).
static func tip_box(title: String, text: String, icon_name: String, width_em := 13.0) -> PanelContainer:
	var col := vbox(0.15)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	var head := hbox(0.3)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.add_child(icon(icon_name, Pal.GOLD, 1.0))
	head.add_child(label(title, 0.8, Pal.GOLD))
	col.add_child(head)
	var body := rich(Keywords.highlight(text, Pal.GOLD), 0.75, Pal.TIP_TEXT)
	body.custom_minimum_size.x = Pal.em(width_em - 1.2)
	col.add_child(body)
	var s := box(Pal.TIP_BG, Color.BLACK, 0.12, 0.45, 0.0)
	var p := panel(pad(s, 0.55, 0.4), col)
	p.custom_minimum_size.x = Pal.em(width_em)
	return p


## Cartoon button: colored fill, ink border, hard shadow that "presses" in.
static func style_button(b: Button, bg: Color, fg: Color, font_em := 1.1, pad_x_em := 1.3, pad_y_em := 0.5) -> void:
	var normal := pad(box(bg), pad_x_em, pad_y_em)
	var hover := pad(box(bg.lightened(0.08)), pad_x_em, pad_y_em)
	var pressed := pad(box(bg.darkened(0.05), Pal.INK, 0.16, 0.6, 0.08), pad_x_em, pad_y_em)
	pressed.content_margin_top += Pal.em(0.14)
	var disabled := pad(box(Color(bg, 0.45), Color(Pal.INK, 0.45), 0.16, 0.6, 0.22), pad_x_em, pad_y_em)
	disabled.shadow_color = Color(Pal.INK, 0.45)
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled],
			["focus", StyleBoxEmpty.new()], ["hover_pressed", pressed]]:
		b.add_theme_stylebox_override(pair[0], pair[1])
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.45))
	b.add_theme_font_size_override("font_size", roundi(Pal.em(font_em)))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func italic_font() -> FontVariation:
	if _italic == null:
		_italic = FontVariation.new()
		_italic.base_font = ThemeDB.get_project_theme().default_font if ThemeDB.get_project_theme() else ThemeDB.fallback_font
		_italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	return _italic
