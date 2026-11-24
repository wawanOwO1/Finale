class_name AlmanacView
extends Control
## The Almanac window (GRAND_DESIGN §6): tabs of discovered entries, a detail panel, and the
## combination finder on the Recipes tab. Undiscovered entries are a silhouette + "???" + a hint.
## Opening it pauses the game (this node runs while paused). DuelUI decides *when* it may open
## (never in the middle of the rival's turn).
##
## Lives in duel_ui.tscn (node "Almanac"); its layout is in the scene, entries are filled here.

signal closed

const TABS: PackedStringArray = ["Ingredients", "Techniques", "Recipes", "Rivals", "Keywords"]
## Rules words that are not in Keywords.BASE (GRAND_DESIGN §6.1).
const EXTRA_KEYWORDS := [
	{name = "Perfect Order", icon = "check",
			text = "A recipe's steps stacked in Recipe Book order, bottom to top. Its effect is x1.5."},
	{name = "Cooked", icon = "serve",
			text = "The right ingredients in any other order. The dish still cooks, at x1."},
	{name = "Garnish", icon = "hype",
			text = "Ingredients stacked on top of a finished dish. Their Quality counts, and they never break a Perfect Order."},
	{name = "Improvised Dish", icon = "burnt",
			text = "A Serve that matches no recipe: 2 Pressure per ingredient, no Hype."},
	{name = "Chef's Flow", icon = "crown",
			text = "Perfect Serves fill the Flow meter. When it is full, pick 1 of 3 modifiers for the rest of the duel."},
]

## Most tags/ingredients the combination finder takes at once.
@export_range(1, 5) var max_picks := 3
## Size of one entry tile (em).
@export var tile_em := Vector2(7.4, 6.2)
## Width of the detail panel / right page (em).
@export var detail_em := 27.0
@export_group("Book look")
## Leather cover color behind the pages and tabs.
@export var cover_color := Color("#6b4226")
## Page paper color (also the open tab, so it joins the page).
@export var page_color := Color("#f3e3c4")
## Darker paper for boxes on a page (ingredient tiles, dish frame).
@export var page_dark := Color("#e6cfa3")
## Ingredient tile size on a recipe entry (em).
@export var recipe_tile_em := Vector2(3.6, 3.3)
@export_group("")

var almanac: Almanac
var tab := "Ingredients"
## Recipe Book chapter shown on the Recipes tab ("" = every book). The finder ignores it.
var chapter := "basics"
## Combination finder picks: tags ("FAT") or key ingredients ("card:beef").
var picks: PackedStringArray = []
## Selected entry: "card:<id>", "recipe:<id>", "rival:<id>", "keyword:<name>".
var selected := ""
var _was_paused := false


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	%AlmanacClose.pressed.connect(close)
	Ui.style_button(%AlmanacClose, Pal.RED, Color.WHITE, 1.0, 1.2, 0.4)
	for b: Button in %AlmanacTabs.get_children():
		b.pressed.connect(show_tab.bind(String(b.name)))
	%AlmanacDetail.custom_minimum_size.x = Pal.em(detail_em)


func open(a: Almanac) -> void:
	almanac = a
	_was_paused = get_tree().paused
	get_tree().paused = true
	show()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.15)
	show_tab(tab)


func close() -> void:
	if not visible:
		return
	hide()
	get_tree().paused = _was_paused
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode in [KEY_TAB, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		close()


# ================================================================ tabs

func show_tab(name: String) -> void:
	tab = name
	if not selected.begins_with(_kind(name) + ":"):
		selected = ""
	for b: Button in %AlmanacTabs.get_children():
		var on := String(b.name) == tab
		var fresh := _tab_has_new(String(b.name))
		b.text = String(b.name) + (" •" if fresh else "")
		_style_tab(b, on)
	%AlmanacFinder.visible = tab == "Recipes"
	# The ribbon column keeps its width on every tab so the book does not jump sideways.
	for c in %AlmanacChapters.get_children():
		if c is Button:
			c.visible = tab == "Recipes"
	_rebuild()


## Bookmark tab on top of the book: the open one is page-colored and joins the page below.
func _style_tab(b: Button, on: bool) -> void:
	var bg := page_color if on else cover_color.lightened(0.22)
	var fg := Pal.INK if on else Pal.CREAM
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var s := HudKit.box(bg if state == "normal" or on else bg.lightened(0.08), Pal.INK, 0.18, 0.0)
		s.border_width_bottom = 0
		s.content_margin_left = Pal.em(1.0)
		s.content_margin_right = Pal.em(1.0)
		s.content_margin_top = Pal.em(0.45 if on else 0.3)
		s.content_margin_bottom = Pal.em(0.35)
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", roundi(Pal.em(0.95)))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _rebuild() -> void:
	for c in %AlmanacList.get_children():
		%AlmanacList.remove_child(c)
		c.queue_free()
	var entries := _entries(tab)
	if selected == "" and not entries.is_empty():
		selected = entries[0]
	%PageTitle.text = tab.to_upper()
	if tab == "Recipes":
		_fill_chapters()
		_fill_finder()
		_fill_recipes()
	else:
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", roundi(Pal.em(0.5)))
		flow.add_theme_constant_override("v_separation", roundi(Pal.em(0.5)))
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for key in entries:
			flow.add_child(_tile(key))
		%AlmanacList.add_child(flow)
	_fill_detail()
	var known := almanac.count()
	var total := GameDB.all("cards").size() + GameDB.all("recipes").size() + GameDB.all("enemies").size()
	%AlmanacProgress.text = "Found %d / %d" % [known, total]
	# The NEW badges show this once; next time these entries are known.
	for key in entries:
		var parts := key.split(":", true, 1)
		almanac.mark_seen(parts[0], parts[1])


## Entry keys of a tab, in display order.
func _entries(name: String) -> PackedStringArray:
	var out: PackedStringArray = []
	match name:
		"Ingredients", "Techniques":
			var want := CardDef.Type.INGREDIENT if name == "Ingredients" else CardDef.Type.TECHNIQUE
			var list: Array = GameDB.all("cards").filter(func(c: CardDef) -> bool: return c.type == want)
			list.sort_custom(func(a: CardDef, b: CardDef) -> bool: return a.name < b.name)
			for c: CardDef in list:
				out.append("card:" + c.id)
		"Recipes":
			for r in _all_recipes():
				out.append("recipe:" + r.id)
		"Rivals":
			var list: Array = GameDB.all("enemies")
			list.sort_custom(func(a: EnemyDef, b: EnemyDef) -> bool: return a.confidence < b.confidence)
			for e: EnemyDef in list:
				out.append("rival:" + e.id)
		"Keywords":
			for k in _keywords():
				out.append("keyword:" + k.name)
	return out


func _kind(tab_name: String) -> String:
	match tab_name:
		"Recipes":
			return "recipe"
		"Rivals":
			return "rival"
		"Keywords":
			return "keyword"
	return "card"


func _tab_has_new(name: String) -> bool:
	if almanac == null or name == "Keywords":
		return false
	for key in _entries(name):
		var parts := key.split(":", true, 1)
		if almanac.is_new(parts[0], parts[1]):
			return true
	return false


## Every recipe in Recipe Book order (then any recipe outside the books).
func _all_recipes() -> Array[RecipeDef]:
	var out := GameDB.book_recipes(GameDB.ALL_BOOKS)
	for r: RecipeDef in GameDB.all("recipes"):
		if not out.has(r):
			out.append(r)
	return out


func _keywords() -> Array:
	var out: Array = Keywords.all().values()
	out.append_array(EXTRA_KEYWORDS)
	return out


func _known(key: String) -> bool:
	var parts := key.split(":", true, 1)
	match parts[0]:
		"card":
			return almanac.knows_card(parts[1])
		"recipe":
			return almanac.knows_recipe(parts[1])
		"rival":
			return almanac.knows_rival(parts[1])
	return true


func _select(key: String) -> void:
	selected = key
	_rebuild()


# ================================================================ tiles

func _tile(key: String) -> Button:
	var parts := key.split(":", true, 1)
	var known := _known(key)
	var title := "???"
	var icon_name := "tips"
	var color := Pal.INK_SOFT
	match parts[0]:
		"card":
			var c := GameDB.card(parts[1])
			icon_name = c.first_tag() if c.is_ingredient() else "technique"
			color = Pal.tag_color(c.first_tag() if c.is_ingredient() else "technique")
			title = c.name
		"rival":
			var e := GameDB.enemy(parts[1])
			icon_name = "taunt"
			color = Pal.RED
			title = e.name
		"keyword":
			var k := _keyword(parts[1])
			icon_name = k.icon
			color = Pal.ORANGE
			title = k.name
	var b := Button.new()
	b.name = parts[1].validate_node_name()
	b.set_meta("key", key)
	b.custom_minimum_size = tile_em * Pal.EM
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var on := key == selected
	var bg := Pal.CREAM if known else Color("#4a3322")
	var border := Pal.ORANGE if on else Pal.INK
	for pair in [["normal", Ui.box(bg, border, 0.2 if on else 0.13, 0.5, 0.15)],
			["hover", Ui.box(bg.lightened(0.08), border, 0.2 if on else 0.13, 0.5, 0.15)],
			["pressed", Ui.box(bg.darkened(0.05), border, 0.2, 0.5, 0.05)],
			["focus", StyleBoxEmpty.new()]]:
		b.add_theme_stylebox_override(pair[0], pair[1])
	var col := Ui.vbox(0.2)
	Ui.fill(col)
	col.add_child(Ui.icon(icon_name, color if known else Color(0, 0, 0, 0.55), 2.4))
	var l := Ui.label(title if known else "???", 0.8, Pal.INK if known else Color(Pal.CREAM, 0.6),
			HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = Pal.em(tile_em.x - 0.6)
	col.add_child(l)
	b.add_child(col)
	if known and parts[0] != "keyword" and almanac.is_new(parts[0], parts[1]):
		var tag := HudKit.tag("NEW", Pal.RED, Color.WHITE, 0.55)
		tag.position = Vector2(Pal.em(0.25), Pal.em(0.25))
		b.add_child(tag)
	b.pressed.connect(_select.bind(key))
	return b


func _keyword(name: String) -> Dictionary:
	for k in _keywords():
		if k.name == name:
			return k
	return {name = name, icon = "tips", text = ""}


# ================================================================ recipes + finder (§6.3)

func _fill_finder() -> void:
	for c in %FinderChips.get_children():
		%FinderChips.remove_child(c)
		c.queue_free()
	var options: PackedStringArray = CardDef.TAGS.duplicate()
	# Key ingredients (recipe slots by name) you have discovered.
	for r in _all_recipes():
		for slot in r.requires:
			if slot.begins_with("card:") and not options.has(slot) and almanac.knows_card(slot.substr(5)):
				options.append(slot)
	for opt in options:
		%FinderChips.add_child(_finder_chip(opt))
	var clear := Button.new()
	clear.text = "Clear"
	Ui.style_button(clear, Pal.PAPER, Pal.INK, 0.8, 0.6, 0.2)
	clear.disabled = picks.is_empty()
	clear.pressed.connect(func() -> void:
		picks = []
		_rebuild())
	%FinderChips.add_child(clear)
	%FinderHint.text = "Pick up to %d tags or ingredients to find the recipes that use them." % max_picks \
			if picks.is_empty() else "Green steps are your picks. Orange steps are still needed."


func _finder_chip(opt: String) -> Button:
	var on := picks.has(opt)
	var tag := opt
	var text := opt.capitalize()
	if opt.begins_with("card:"):
		var def := GameDB.card(opt.substr(5))
		tag = def.first_tag()
		text = def.name
	var b := Button.new()
	b.name = opt.replace(":", "_").validate_node_name()
	b.set_meta("pick", opt)
	b.text = text
	b.icon = Ui.icon_tex(tag)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", roundi(Pal.em(1.0)))
	var bg := Pal.tag_color(tag) if on else Pal.CREAM
	var fg := (Pal.CREAM if tag in ["VEGGIE", "SPICE", "SAUCE"] else Pal.INK) if on else Pal.INK
	Ui.style_button(b, bg, fg, 0.75, 0.45, 0.15)
	b.add_theme_color_override("icon_normal_color", fg if on else Pal.tag_color(tag))
	b.add_theme_color_override("icon_hover_color", fg if on else Pal.tag_color(tag))
	b.add_theme_color_override("icon_pressed_color", fg)
	b.disabled = not on and picks.size() >= max_picks
	b.pressed.connect(_toggle_pick.bind(opt))
	return b


func _toggle_pick(opt: String) -> void:
	if picks.has(opt):
		picks.remove_at(picks.find(opt))
	elif picks.size() < max_picks:
		picks.append(opt)
	_rebuild()


## Chapter ribbons sticking out of the book's right edge, one per Recipe Book (+ "All").
func _fill_chapters() -> void:
	for c in %AlmanacChapters.get_children():
		if c is Button:
			%AlmanacChapters.remove_child(c)
			c.queue_free()
	var ids: PackedStringArray = GameDB.ALL_BOOKS.duplicate()
	ids.append("")
	for id in ids:
		var b := Button.new()
		b.name = ("Chapter_" + (id if id != "" else "all")).validate_node_name()
		b.text = id.capitalize() if id != "" else "All"
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var on := picks.is_empty() and id == chapter
		var color: Color = DuelUI.BOOK_COLORS.get(id, Pal.INK_SOFT)
		if not picks.is_empty():
			color = color.lerp(Pal.INK_SOFT, 0.6)
		HudKit.style_ribbon(b, color)
		b.add_theme_font_size_override("font_size", roundi(Pal.em(0.95)))
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(c, Pal.CREAM)
		# The open chapter sticks out further.
		b.custom_minimum_size.x = Pal.em(8.2 if on else 7.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(_set_chapter.bind(id))
		%AlmanacChapters.add_child(b)


func _set_chapter(id: String) -> void:
	chapter = id
	picks = []
	selected = ""
	_rebuild()


func _fill_recipes() -> void:
	var shown: Array[RecipeDef] = []
	var covered := {}
	if picks.is_empty():
		for r in _all_recipes():
			if chapter == "" or r.book == chapter:
				shown.append(r)
		var book := GameDB.book(chapter) if chapter != "" else null
		%PageTitle.text = book.name.to_upper() if book else "ALL RECIPES"
	else:
		var pool: Array[RecipeDef] = []
		for r in _all_recipes():
			if almanac.knows_recipe(r.id):
				pool.append(r)
		for h in Almanac.find(pool, picks):
			shown.append(h.recipe)
			covered[h.recipe.id] = h.covered
		%PageTitle.text = "RECIPES WITH YOUR PICKS"
	if shown.is_empty():
		%AlmanacList.add_child(Ui.label("No recipe you know uses all of these.", 0.9, Pal.INK_SOFT))
	elif not shown.any(func(r: RecipeDef) -> bool: return "recipe:" + r.id == selected):
		selected = "recipe:" + shown[0].id
	for r in shown:
		var cov: Array[bool] = []
		if covered.has(r.id):
			cov.assign(covered[r.id])
		%AlmanacList.add_child(_recipe_row(r, cov))


## One recipe entry, like a cookbook page line: dish box, dark name ribbon, the ingredient
## tiles in Perfect Order (left = bottom of the stack), and what it does.
## `covered` (finder): which steps your picks fill (green); the rest are still needed (orange).
func _recipe_row(r: RecipeDef, covered: Array[bool]) -> Button:
	var key := "recipe:" + r.id
	var known := almanac.knows_recipe(r.id)
	var on := key == selected
	var b := Button.new()
	b.name = r.id.validate_node_name()
	b.set_meta("key", key)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := page_dark if known else Color("#4a3322")
	var border := Pal.ORANGE if on else Pal.INK
	for pair in [["normal", HudKit.box(bg, border, 0.2 if on else 0.14, 0.22)],
			["hover", HudKit.box(bg.lightened(0.06), border, 0.2 if on else 0.14, 0.22)],
			["pressed", HudKit.box(bg.darkened(0.04), Pal.ORANGE, 0.2, 0.08)],
			["focus", StyleBoxEmpty.new()]]:
		b.add_theme_stylebox_override(pair[0], pair[1])

	var row := Ui.hbox(0.6)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(_dish_box(r, known, 4.6))
	var col := Ui.vbox(0.35)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Name ribbon (dark bar, cream caps) with the source on its right.
	var ribbon := Ui.hbox(0.4)
	var name_l := Ui.label((r.name if known else "???").to_upper(), 1.0, Pal.CREAM if known else Color(Pal.CREAM, 0.5))
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ribbon.add_child(name_l)
	if known and almanac.is_new("recipe", r.id):
		ribbon.add_child(HudKit.tag("NEW", Pal.RED, Color.WHITE, 0.55))
	col.add_child(Ui.panel(Ui.pad(HudKit.box(Pal.HUD_PANEL, Pal.HUD_INK, 0.12, 0.0), 0.5, 0.12), ribbon))

	var tiles := Ui.hbox(0.3)
	tiles.alignment = BoxContainer.ALIGNMENT_BEGIN
	for i in r.requires.size():
		var ring := Color.TRANSPARENT
		if not covered.is_empty():
			ring = Pal.GREEN if covered[i] else Pal.ORANGE
		var t := _ingredient_tile(r.requires[i], known, ring)
		if not covered.is_empty():
			t.set_meta("covered", covered[i])
		tiles.add_child(t)
	col.add_child(tiles)

	var stats := _stats_line(r) if known else _source_text(r)
	col.add_child(Ui.label(stats, 0.7, Pal.INK_SOFT if known else Color(Pal.CREAM, 0.55)))
	row.add_child(col)

	var holder := Ui.panel(Ui.pad(StyleBoxEmpty.new(), 0.45, 0.4), row)
	Ui.fill(holder)
	b.add_child(holder)
	b.custom_minimum_size.y = Pal.em(recipe_tile_em.y + 4.6)
	b.pressed.connect(_select.bind(key))
	return b


## Square "plate" with the dish's main ingredient (key ingredient, else the first tag),
## framed in its chapter color. A dark "?" when the recipe is still undiscovered.
func _dish_box(r: RecipeDef, known: bool, size_em: float) -> Control:
	var main_req := r.requires[0] if not r.requires.is_empty() else "PROTEIN"
	for req in r.requires:
		if req.begins_with("card:"):
			main_req = req
			break
	var tag := GameDB.card(main_req.substr(5)).first_tag() if main_req.begins_with("card:") else main_req
	var frame: Color = DuelUI.BOOK_COLORS.get(r.book, Pal.INK_SOFT)
	var s := HudKit.box(Pal.CREAM if known else Color(0, 0, 0, 0.3), frame if known else Pal.INK, 0.22, 0.0)
	var c := CenterContainer.new()
	c.custom_minimum_size = Vector2.ONE * Pal.em(size_em)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if known:
		c.add_child(Ui.icon_shadowed(tag, Pal.tag_color(tag), size_em * 0.6, 0.12))
	else:
		c.add_child(Ui.label("?", size_em * 0.35, Color(Pal.CREAM, 0.5)))
	var p := Ui.panel(s, c)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


## One ingredient tile (icon over its name). Key ingredients sit on gold.
func _ingredient_tile(req: String, known: bool, ring := Color.TRANSPARENT) -> Control:
	var tag := req
	var text := req.capitalize()
	var bg := Pal.CREAM
	if req.begins_with("card:"):
		var def := GameDB.card(req.substr(5))
		tag = def.first_tag()
		text = def.name
		bg = Pal.GOLD
	var col := Ui.vbox(0.05)
	col.custom_minimum_size = Pal.em(1.0) * recipe_tile_em
	if known:
		col.add_child(Ui.icon(tag, Pal.tag_color(tag) if bg != Pal.GOLD else Pal.INK, recipe_tile_em.y * 0.5))
		var l := Ui.label(text, 0.62, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER)
		l.clip_text = true
		l.custom_minimum_size.x = Pal.em(recipe_tile_em.x - 0.3)
		col.add_child(l)
	else:
		bg = Color(0, 0, 0, 0.3)
		col.add_child(Ui.label("?", 1.2, Color(Pal.CREAM, 0.5), HORIZONTAL_ALIGNMENT_CENTER))
	var s := HudKit.box(bg, ring if ring.a > 0.0 else Pal.INK, 0.22 if ring.a > 0.0 else 0.12, 0.0)
	return Ui.panel(Ui.pad(s, 0.1, 0.15), col)


## "10 PRESSURE · 5 COMPOSURE · +25 HYPE"
func _stats_line(r: RecipeDef) -> String:
	var parts: PackedStringArray = []
	for e in r.effects:
		parts.append(_effect_words(e).to_upper())
	parts.append("+%d HYPE" % r.hype)
	return "  ·  ".join(parts)


func _effect_words(e: EffectDef) -> String:
	match e.kind:
		EffectDef.Kind.PRESSURE:
			return "%d Pressure" % e.amount
		EffectDef.Kind.COMPOSURE:
			return "%d Composure" % e.amount
		EffectDef.Kind.HEAL:
			return "Heal %d" % e.amount
		EffectDef.Kind.DRAW:
			return "Draw %d" % e.amount
		EffectDef.Kind.HYPE:
			return "Hype +%d" % e.amount
		EffectDef.Kind.STATUS:
			return "%s %d" % [e.status.capitalize(), e.amount]
		EffectDef.Kind.CLEANSE:
			return "Cleanse"
	return ""


func _effect_icon(e: EffectDef) -> String:
	match e.kind:
		EffectDef.Kind.PRESSURE:
			return "pressure"
		EffectDef.Kind.COMPOSURE:
			return "composure"
		EffectDef.Kind.HEAL:
			return "confidence"
		EffectDef.Kind.DRAW:
			return "draw"
		EffectDef.Kind.HYPE:
			return "hype"
		EffectDef.Kind.STATUS:
			return e.status
	return "buff"


## "Basics Cookbook", "Seen from Tony", or the hint for an undiscovered recipe.
func _source_text(r: RecipeDef) -> String:
	var book := GameDB.book(r.book) if r.book != "" else null
	var book_name := book.name if book else "a Recipe Book"
	var src := almanac.recipe_source(r.id)
	if src == "":
		return "Found in %s" % book_name
	if src == Almanac.MASTERED:
		return book_name
	var e := GameDB.enemy(src)
	return "Seen from %s" % (e.name if e else src)


# ================================================================ detail

func _fill_detail() -> void:
	var box: VBoxContainer = %DetailBox
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
	if selected == "":
		return
	var parts := selected.split(":", true, 1)
	if not _known(selected):
		_detail_locked(box, parts[0], parts[1])
		return
	match parts[0]:
		"card":
			_detail_card(box, GameDB.card(parts[1]))
		"recipe":
			_detail_recipe(box, GameDB.recipe(parts[1]))
		"rival":
			_detail_rival(box, GameDB.enemy(parts[1]))
		"keyword":
			var k := _keyword(parts[1])
			box.add_child(_head(k.icon, Pal.ORANGE, k.name, "Keyword"))
			box.add_child(_body(k.text))


func _head(icon_name: String, color: Color, title: String, kicker: String) -> Control:
	var row := Ui.hbox(0.5)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(Ui.icon(icon_name, color, 2.6))
	var col := Ui.vbox(0.0)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.add_child(Ui.label(kicker.to_upper(), 0.65, Pal.INK_SOFT))
	var t := Ui.label(title, 1.35)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = Pal.em(detail_em - 6.6)
	col.add_child(t)
	row.add_child(col)
	return row


func _body(text: String, size_em := 0.85) -> RichTextLabel:
	var r := Ui.rich(Keywords.highlight(text), size_em)
	r.custom_minimum_size.x = Pal.em(detail_em - 2.8)
	return r


func _section(title: String) -> Label:
	return Ui.label(title.to_upper(), 0.65, Pal.INK_SOFT)


func _detail_locked(box: VBoxContainer, kind: String, id: String) -> void:
	var hint := ""
	match kind:
		"card":
			var c := GameDB.card(id)
			hint = "Not in your deck yet."
			for r in _all_recipes():
				if r.requires.has("card:" + id):
					var b := GameDB.book(r.book)
					hint = "A key ingredient in %s." % (b.name if b else "a Recipe Book")
					break
		"recipe":
			hint = _source_text(GameDB.recipe(id)) + ". Master the book, or watch a rival serve it."
		"rival":
			hint = "Meet them on the Course Path."
	box.add_child(_head("tips", Color(0, 0, 0, 0.45), "???", "Undiscovered"))
	box.add_child(_body(hint))


func _detail_card(box: VBoxContainer, c: CardDef) -> void:
	var ing := c.is_ingredient()
	var tag := c.first_tag() if ing else "technique"
	box.add_child(_head(tag, Pal.tag_color(tag), c.name, "Ingredient" if ing else "Technique"))
	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", roundi(Pal.em(0.3)))
	facts.add_theme_constant_override("v_separation", roundi(Pal.em(0.3)))
	facts.add_child(HudKit.tag("COST %d HEAT" % c.cost, Pal.ORANGE, Color.WHITE, 0.65))
	if ing:
		for t in c.tags:
			facts.add_child(HudKit.tag(t, Pal.tag_color(t), Pal.CREAM if t in ["VEGGIE", "SPICE", "SAUCE"] else Pal.INK, 0.65))
		facts.add_child(HudKit.tag("QUALITY %d" % c.quality, Pal.GOLD, Pal.INK, 0.65))
	if c.retain:
		facts.add_child(HudKit.tag("RETAIN", Pal.BLUE, Color.WHITE, 0.65))
	if c.exhaust:
		facts.add_child(HudKit.tag("EXHAUST", Pal.INK, Pal.CREAM, 0.65))
	box.add_child(facts)
	if c.text != "":
		box.add_child(_body(c.text))
	if ing:
		box.add_child(_section("Used in"))
		var hidden := 0
		var names: PackedStringArray = []
		for r in Almanac.uses_of(c, _all_recipes()):
			if almanac.knows_recipe(r.id):
				names.append(r.name)
			else:
				hidden += 1
		if hidden > 0:
			names.append("%d undiscovered" % hidden)
		box.add_child(_body(", ".join(names) if not names.is_empty() else "No recipe needs it.", 0.8))


## Right page for a recipe (cookbook spread): the dish as a stack on its plate, name and chapter,
## then the cooking order on the left and a dark stats box on the right.
func _detail_recipe(box: VBoxContainer, r: RecipeDef) -> void:
	var color: Color = DuelUI.BOOK_COLORS.get(r.book, Pal.INK_SOFT)
	# Dish frame: the Perfect Order as a stack, bottom step on the plate.
	var stack := Ui.vbox(0.12)
	stack.alignment = BoxContainer.ALIGNMENT_END
	for i in range(r.requires.size() - 1, -1, -1):
		var req := r.requires[i]
		var tag := GameDB.card(req.substr(5)).first_tag() if req.begins_with("card:") else req
		var layer := Ui.hbox(0.3)
		layer.add_child(Ui.icon(tag, Pal.INK, 1.1))
		var layer_box := Ui.panel(Ui.pad(HudKit.box(Pal.tag_color(tag), Pal.INK, 0.14, 0.0), 0.5, 0.08), layer)
		layer_box.custom_minimum_size.x = Pal.em(7.0 + (r.requires.size() - i) * 0.5)
		layer_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(layer_box)
	var plate := ColorRect.new()
	plate.color = Pal.CREAM
	plate.custom_minimum_size = Vector2(Pal.em(13.0), Pal.em(0.5))
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(plate)
	var frame := Ui.panel(Ui.pad(HudKit.box(page_dark, Pal.INK, 0.16, 0.0), 0.8, 0.7), stack)
	frame.custom_minimum_size.y = Pal.em(9.5)
	box.add_child(frame)

	var title := Ui.label("◆  %s  ◆" % r.name.to_upper(), 1.45, Pal.RED_DARK, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(title)
	box.add_child(Ui.label(("%s · %s cuisine" % [_source_text(r), RecipeDef.cuisine_name(r.cuisine)]).to_upper(),
			0.75, color.darkened(0.2), HORIZONTAL_ALIGNMENT_CENTER))

	var cols := Ui.hbox(0.6)
	cols.alignment = BoxContainer.ALIGNMENT_BEGIN
	# Cooking order, bottom of the stack first.
	var order := Ui.vbox(0.25)
	order.alignment = BoxContainer.ALIGNMENT_BEGIN
	order.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order.add_child(_section("Cooking order (bottom first)"))
	for i in r.requires.size():
		var req := r.requires[i]
		var tag := req
		var text := "Any " + req.capitalize()
		if req.begins_with("card:"):
			var def := GameDB.card(req.substr(5))
			tag = def.first_tag()
			text = def.name
		var line := Ui.hbox(0.4)
		line.alignment = BoxContainer.ALIGNMENT_BEGIN
		line.add_child(Ui.label(str(i + 1), 0.75, Pal.INK_SOFT))
		line.add_child(Ui.icon(tag, Pal.tag_color(tag), 1.1))
		line.add_child(Ui.label(text, 0.85))
		var bg := Pal.GOLD.lightened(0.35) if req.begins_with("card:") else page_dark
		order.add_child(Ui.panel(Ui.pad(HudKit.box(bg, Pal.INK, 0.1, 0.0), 0.4, 0.12), line))
	cols.add_child(order)

	# Stats box (dark, like a chalk slate).
	var stats := Ui.vbox(0.3)
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	for e in r.effects:
		stats.add_child(_stat_row(_effect_icon(e), _effect_words(e), Pal.CREAM))
	stats.add_child(_stat_row("hype", "Hype +%d" % r.hype, Pal.GOLD))
	stats.add_child(_stat_row("check", "Perfect x%s" % Duel.PERFECT_ORDER_MULT, Pal.GREEN.lightened(0.3)))
	var slate := Ui.panel(Ui.pad(HudKit.box(Pal.HUD_PANEL, Pal.HUD_INK, 0.16, 0.0), 0.6, 0.5), stats)
	slate.custom_minimum_size.x = Pal.em(10.5)
	slate.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cols.add_child(slate)
	box.add_child(cols)

	box.add_child(_body("The first effect also gets + Quality of every ingredient on the plate. " +
			"Stack the steps in this order for a Perfect Order (x%s); any other order still cooks." % Duel.PERFECT_ORDER_MULT, 0.75))
	var src := almanac.recipe_source(r.id)
	if src != Almanac.MASTERED:
		box.add_child(_body("You have not mastered this book. Its Order Ticket will not guide you.", 0.75))


func _stat_row(icon_name: String, text: String, color: Color) -> Control:
	var row := Ui.hbox(0.35)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(Ui.icon(icon_name, color, 1.1))
	row.add_child(Ui.label(text, 0.85, color))
	return row


func _detail_rival(box: VBoxContainer, e: EnemyDef) -> void:
	box.add_child(_head("taunt", Pal.RED, e.name, e.title))
	var facts := HFlowContainer.new()
	facts.add_theme_constant_override("h_separation", roundi(Pal.em(0.3)))
	facts.add_child(HudKit.tag("CONFIDENCE %d" % e.confidence, Pal.RED, Color.WHITE, 0.65))
	if e.drafts():
		facts.add_child(HudKit.tag("HEAT %d" % e.max_heat, Pal.ORANGE, Color.WHITE, 0.65))
		facts.add_child(HudKit.tag("HAND %d" % e.hand_size, Pal.BLUE, Color.WHITE, 0.65))
	if e.boss:
		facts.add_child(HudKit.tag("BOSS", Pal.INK, Pal.GOLD, 0.65))
	box.add_child(facts)
	# Cuisine (GDD §4.11): Specialty is public, the weakness shows once you have hit it.
	box.add_child(_section("Cuisine"))
	var weak := almanac.known_weaknesses(e.id)
	var weak_text := "???"
	if not weak.is_empty():
		weak_text = ", then ".join(Array(weak).map(func(c: String) -> String: return RecipeDef.cuisine_name(c)))
	elif e.weakness == RecipeDef.HOME:
		weak_text = "None"
	box.add_child(_body("Home: %s. Your %s dishes hit for less.\nWeak to: %s%s" % [
			RecipeDef.cuisine_name(e.specialty), RecipeDef.cuisine_name(e.specialty), weak_text,
			". Hit it and they are Stumped." if not weak.is_empty() else ". Serve the right dish to find out."], 0.8))
	box.add_child(_section("Gimmick"))
	if almanac.rival_finished(e.id):
		box.add_child(_body(e.gimmick if e.gimmick != "" else "No tricks. Just cooking."))
	else:
		box.add_child(_body("??? Finish a duel with %s to find out." % e.name, 0.8))
	box.add_child(_section("Dishes served"))
	var names: PackedStringArray = []
	for id in almanac.served_by(e.id):
		var r := GameDB.recipe(id)
		if r:
			names.append(r.name)
	box.add_child(_body(", ".join(names) if not names.is_empty() else "None seen yet.", 0.8))
