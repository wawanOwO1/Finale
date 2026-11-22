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
## Width of the detail panel (em).
@export var detail_em := 21.0

var almanac: Almanac
var tab := "Ingredients"
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
		Ui.style_button(b, Pal.INK if on else Pal.PAPER, Pal.CREAM if on else Pal.INK, 0.95, 0.9, 0.3)
	%AlmanacFinder.visible = tab == "Recipes"
	_rebuild()


func _rebuild() -> void:
	for c in %AlmanacList.get_children():
		%AlmanacList.remove_child(c)
		c.queue_free()
	var entries := _entries(tab)
	if selected == "" and not entries.is_empty():
		selected = entries[0]
	if tab == "Recipes":
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


func _fill_recipes() -> void:
	if picks.is_empty():
		for r in _all_recipes():
			%AlmanacList.add_child(_recipe_row(r, []))
		return
	var pool: Array[RecipeDef] = []
	for r in _all_recipes():
		if almanac.knows_recipe(r.id):
			pool.append(r)
	var hits := Almanac.find(pool, picks)
	if hits.is_empty():
		%AlmanacList.add_child(Ui.label("No recipe you know uses all of these.", 0.9, Pal.INK_SOFT))
	elif not hits.any(func(h: Dictionary) -> bool: return "recipe:" + h.recipe.id == selected):
		selected = "recipe:" + hits[0].recipe.id
	for h in hits:
		%AlmanacList.add_child(_recipe_row(h.recipe, h.covered))


## One recipe line: name, Perfect Order chips (bottom → top), where it comes from.
## `covered` (finder): which steps your picks fill; the rest are outlined as still needed.
func _recipe_row(r: RecipeDef, covered: Array[bool]) -> Button:
	var key := "recipe:" + r.id
	var known := almanac.knows_recipe(r.id)
	var b := Button.new()
	b.name = r.id.validate_node_name()
	b.set_meta("key", key)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var on := key == selected
	var bg := Color(1, 1, 1, 0.55) if known else Color("#4a3322")
	var border := Pal.ORANGE if on else Color.TRANSPARENT
	for pair in [["normal", Ui.box(bg, border, 0.16, 0.5, 0.0)],
			["hover", Ui.box(bg.lightened(0.1), border if on else Pal.INK_SOFT, 0.16, 0.5, 0.0)],
			["pressed", Ui.box(bg, Pal.ORANGE, 0.16, 0.5, 0.0)], ["focus", StyleBoxEmpty.new()]]:
		b.add_theme_stylebox_override(pair[0], pair[1])
	var row := Ui.hbox(0.7)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var name_l := Ui.label(r.name if known else "???", 0.95, Pal.INK if known else Color(Pal.CREAM, 0.6))
	name_l.custom_minimum_size.x = Pal.em(9)
	row.add_child(name_l)
	var seq := Ui.hbox(0.2)
	for i in r.requires.size():
		if i > 0:
			seq.add_child(Ui.icon("arrow", Pal.INK_SOFT if known else Color(Pal.CREAM, 0.4), 0.7))
		if known:
			seq.add_child(_step(r.requires[i], covered, i))
		else:
			seq.add_child(Ui.panel(Ui.pad(Ui.box(Color(0, 0, 0, 0.3), Color.TRANSPARENT, 0.0, 0.45, 0.0), 0.5, 0.1),
					Ui.label("?", 0.8, Color(Pal.CREAM, 0.5))))
	row.add_child(seq)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	var source := _source_text(r)
	row.add_child(Ui.label(source, 0.7, Pal.INK_SOFT if known else Color(Pal.CREAM, 0.55)))
	if known and almanac.is_new("recipe", r.id):
		row.add_child(HudKit.tag("NEW", Pal.RED, Color.WHITE, 0.55))
	var holder := Ui.panel(Ui.pad(StyleBoxEmpty.new(), 0.6, 0.35), row)
	Ui.fill(holder)
	b.add_child(holder)
	b.custom_minimum_size.y = Pal.em(2.9)
	b.pressed.connect(_select.bind(key))
	return b


func _step(req: String, covered: Array[bool], i: int) -> Control:
	var chip := Ui.req_chip(req)
	if covered.is_empty():
		return chip
	var ring := Pal.GREEN if covered[i] else Pal.ORANGE
	var p := Ui.panel(Ui.pad(Ui.box(Color.TRANSPARENT, ring, 0.18, 0.5, 0.0), 0.08, 0.05), chip)
	p.set_meta("covered", covered[i])
	return p


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
	t.custom_minimum_size.x = Pal.em(detail_em - 5.5)
	col.add_child(t)
	row.add_child(col)
	return row


func _body(text: String, size_em := 0.85) -> RichTextLabel:
	var r := Ui.rich(Keywords.highlight(text), size_em)
	r.custom_minimum_size.x = Pal.em(detail_em - 1.6)
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


func _detail_recipe(box: VBoxContainer, r: RecipeDef) -> void:
	box.add_child(_head("book", Pal.RED, r.name, _source_text(r)))
	box.add_child(_section("Perfect Order (bottom to top)"))
	var seq := HFlowContainer.new()
	seq.add_theme_constant_override("h_separation", roundi(Pal.em(0.2)))
	seq.add_theme_constant_override("v_separation", roundi(Pal.em(0.3)))
	for i in r.requires.size():
		if i > 0:
			seq.add_child(Ui.icon("arrow", Pal.INK_SOFT, 0.7))
		seq.add_child(Ui.req_chip(r.requires[i]))
	box.add_child(seq)
	box.add_child(_section("Effect"))
	box.add_child(_body("%s, + Quality. Perfect Order x%s. Hype +%d." % [r.text.trim_suffix("."),
			Duel.PERFECT_ORDER_MULT, r.hype]))
	var src := almanac.recipe_source(r.id)
	if src != Almanac.MASTERED:
		box.add_child(_body("You have not mastered this book. Its Order Ticket will not guide you.", 0.75))


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
