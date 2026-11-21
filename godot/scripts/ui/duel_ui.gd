class_name DuelUI
extends CanvasLayer
## Duel HUD (GDD §7.2), the Godot port of the old ui/hud.ts + ui/drag.ts.
## Placement of every block lives in duel_ui.tscn (move them in the 2D editor); this script
## fills them from the Duel state on `changed`, runs the card drag, tooltips and feedback.
##
## Cards are DRAGGED: ingredients onto the Prep Board, techniques up out of the hand.
## Shortcuts: E = End Turn, S = Serve, P = pixel filter.

signal restart_requested
signal pixel_toggled

const CARD_VIEW := preload("res://scenes/ui/card_view.tscn")
const DRAG_THRESHOLD := 6.0
## Techniques play when released above this fraction of the screen height.
const PLAY_ZONE_FRAC := 0.66
const CUTIN_SHADER := """
shader_type canvas_item;
uniform float spin = 0.0;
uniform float aspect = 1.7778;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p) / aspect * 1.6;
	vec3 c = mix(vec3(1.0, 0.824, 0.353), vec3(0.949, 0.439, 0.165), smoothstep(0.0, 0.45, r));
	c = mix(c, vec3(0.847, 0.204, 0.173), smoothstep(0.45, 1.0, r));
	float a = degrees(atan(p.y, p.x)) + 180.0 + spin;
	if (mod(a, 5.0) > 4.0) c = mix(c, vec3(1.0), 0.8);
	COLOR = vec4(c, 1.0);
}
"""

var duel: Duel
## Screen positions of the 3D anchors, pushed every frame by main.gd.
var anchors := {rival = Vector2(1400, 300), player = Vector2(600, 400), board = Vector2(300, 400)}

var _views: Array[CardView] = []
var _prev_hand := {}
var _placed_uid := -1
var _hover: CardView
var _drag := {}
var _busy := false
var _slots: Array[PanelContainer] = []
var _hype_pulse: Tween
var _serve_pulse: Tween
var _toast_tw: Tween
var _banner_tw: Tween
var _cutin_tw: Tween
var _tip_owner: Control
## Last mouse position in HUD coordinates (from events, so it also works with pushed input).
var _mouse := Vector2(-1000, -1000)


func _ready() -> void:
	%ServeButton.pressed.connect(func() -> void: if duel: duel.serve())
	%EndTurn.pressed.connect(func() -> void: if duel: duel.end_turn())
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%PixelButton.pressed.connect(func() -> void: pixel_toggled.emit())
	_build_static()
	for n in [%Cookbook, %Overlay, %Toast, %DishBanner, %CutIn, %PlayZone, %Tooltip]:
		n.hide()


# ================================================================ public API

## Pre-duel Recipe Book (the book is closed during the duel: memorize the orders).
## Await it: `await ui.show_cookbook(recipes)`.
func show_cookbook(recipes: Array[RecipeDef]) -> void:
	%Overlay.hide()
	for child in %BookList.get_children():
		child.queue_free()
	for r in recipes:
		%BookList.add_child(_book_row(r))
	%Cookbook.show()
	_pop_in(%BookBox)
	await %StartButton.pressed
	%Cookbook.hide()


func bind(d: Duel) -> void:
	duel = d
	_prev_hand = {}
	%VenueSub.text = "vs %s" % d.enemy_def.name
	d.changed.connect(_refresh)
	d.signature_served.connect(_play_cutin)
	d.dish_revealed.connect(_show_dish)
	d.confidence_lost.connect(func(target: String, amount: int, source: String) -> void:
		_float(_anchor(target), "-%d" % amount, Pal.ORANGE if source == "spicy" else Pal.RED, 2.3))
	d.pressure_dealt.connect(func(target: String, _amount: int, blocked: int) -> void:
		if blocked > 0:
			_float(_anchor(target), str(blocked), Pal.BLUE, 1.4, "composure"))
	d.composure_gained.connect(func(target: String, amount: int) -> void:
		_float(_anchor(target), "+%d" % amount, Pal.BLUE, 1.4, "composure", 0.12))
	d.status_applied.connect(func(target: String, status: String, amount: int) -> void:
		var bad := StatusDefs.is_debuff(status)
		_float(_anchor(target), "%s %d" % [StatusDefs.display_name(status), amount],
				Color("#b46ad6") if bad else Color("#7ac36a"), 1.1, status, 0.24))
	_refresh()


func set_pixel_on(on: bool) -> void:
	var b: Button = %PixelButton
	Ui.style_button(b, Pal.INK if on else Pal.CREAM, Pal.CREAM if on else Pal.INK, 1.0, 0.3, 0.3)
	%PixelIcon.self_modulate = Pal.CREAM if on else Pal.INK


# ================================================================ static build

func _build_static() -> void:
	# Top bar
	_tip(%HypeMeter, "Hype", Keywords.BASE.Hype.text, "hype")
	_tip(%PixelButton, "Pixel filter", "Toggle the low-res pixel look. Shortcut: P.", "pixel")
	set_pixel_on(false)
	# Badges with icons
	%HpBadge.add_child(_badge_bg("confidence", Pal.RED, 6.5, 0.2))
	%HpBadge.move_child(%HpBadge.get_child(-1), 0)
	_tip(%HpBadge, "Confidence", Keywords.BASE.Confidence.text, "confidence")
	%HeatOrb.add_child(_badge_bg("heat", Pal.ORANGE, 4.4, 0.18))
	%HeatOrb.move_child(%HeatOrb.get_child(-1), 0)
	_tip(%HeatOrb, "Heat", Keywords.BASE.Heat.text, "heat")
	for b in [%EnemyBlock, %PlayerBlock]:
		var big: bool = b == %PlayerBlock
		b.add_child(_badge_bg("composure", Pal.BLUE, 2.8 if big else 1.9, 0.1))
		b.move_child(b.get_child(-1), 0)
		_tip(b, "Composure", Keywords.BASE.Composure.text, "composure")
	_tip(%DrawPile, "Draw pile", "Cards you will draw. Shuffled from the discard pile when empty.", "draw")
	_tip(%DiscardPile, "Discard pile", "Played and discarded cards. Shuffled back when the draw pile runs out.", "discard")
	_tip(%ServeButton, "Serve", Keywords.BASE.Serve.text, "serve")
	# Buttons
	Ui.style_button(%EndTurn, Pal.CREAM, Pal.INK, 1.1, 1.3, 0.6)
	Ui.style_button(%StartButton, Pal.RED, Color.WHITE, 1.1, 1.6, 0.6)
	Ui.style_button(%RestartButton, Pal.RED, Color.WHITE, 1.1, 1.6, 0.6)
	_style_serve(false)
	# Prep Board slots with arrows between
	for i in Duel.PLATE_SIZE:
		if i > 0:
			%Slots.add_child(Ui.icon("arrow", Color(Pal.INK, 0.33), 0.8))
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(Pal.em(4), Pal.em(5))
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%Slots.add_child(slot)
		_slots.append(slot)
	# Cut-in background
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CUTIN_SHADER
	mat.shader = sh
	%CutInRays.material = mat
	%CutInSfx.add_theme_font_override("font", Ui.italic_font())


func _badge_bg(icon_name: String, color: Color, size_em: float, shadow_em: float) -> Control:
	var bg := Ui.icon_shadowed(icon_name, color, size_em, shadow_em)
	Ui.fill(bg)
	return bg


# ================================================================ render

func _refresh() -> void:
	if duel == null:
		return
	var d := duel
	var live := d.phase == "player"

	# Rival
	%Intent.visible = live
	if live:
		_fill_intent(d.intent())
	%RivalName.text = d.enemy_def.name
	%RivalTitle.text = d.enemy_def.title
	%HpFill.anchor_right = float(d.enemy.confidence) / d.enemy.max_confidence
	%HpText.text = "%d / %d" % [d.enemy.confidence, d.enemy.max_confidence]
	_block_badge(%EnemyBlock, d.enemy.composure)
	_fill_statuses(%EnemyStatuses, d.enemy)
	%Rival.reset_size()

	# Player
	%PlayerConf.text = str(d.player.confidence)
	%PlayerConfMax.text = "/%d" % d.player.max_confidence
	_block_badge(%PlayerBlock, d.player.composure)
	_fill_statuses(%PlayerStatuses, d.player)
	%HeatValue.text = str(d.player.heat)
	%HeatMax.text = "/%d" % Duel.MAX_HEAT
	var heat_icon: TextureRect = %HeatOrb.get_child(0).get_node("Icon")
	heat_icon.self_modulate = Color("#9b8a76") if d.player.heat == 0 else Pal.ORANGE
	%DrawCount.text = str(d.draw_pile.size())
	%DiscardCount.text = str(d.discard.size())

	# Hype
	var full := d.hype >= Duel.MAX_HYPE or d.signature_armed
	%HypeFill.anchor_right = float(d.hype) / Duel.MAX_HYPE
	%HypeFill.get_theme_stylebox("panel").bg_color = Pal.ORANGE if full else Pal.GOLD
	%HypeValue.text = str(d.hype)
	_hype_pulse = _pulse(%HypeFill, full, _hype_pulse)

	# Hand
	_rebuild_hand(live)

	# Prep Board: ingredients in placement order. The book is closed: no recipe hints.
	for i in _slots.size():
		_fill_slot(_slots[i], d.plate[i] if i < d.plate.size() else null, i)
	_placed_uid = -1
	%BoardCount.text = "%d/%d" % [d.plate.size(), Duel.PLATE_SIZE]
	%Board.visible = live
	%ServeButton.disabled = not d.can_serve().ok
	_style_serve(d.signature_armed)
	%EndTurn.disabled = not live

	# End of duel
	%Overlay.visible = not live
	if not live:
		var won := d.phase == "won"
		%ResultTitle.text = "Victory" if won else "Defeat"
		%ResultTitle.add_theme_color_override("font_color", Pal.RED if won else Pal.INK_SOFT)
		%ResultText.text = ("%s gives up in %d turns. Confidence left: %d." % [d.enemy_def.name, d.turn, d.player.confidence]) \
				if won else ("%s out-cooked you this time." % d.enemy_def.name)
		_pop_in(%EndBox)


func _fill_intent(it: IntentDef) -> void:
	for c in %IntentParts.get_children():
		c.queue_free()
	var said: PackedStringArray = []
	if it.has_attack():
		var v := duel.pressure_from("enemy", it.attack)
		%IntentParts.add_child(_intent_part("pressure", Pal.RED, v))
		said.append("deal %d Pressure" % v)
	if it.block > 0:
		%IntentParts.add_child(_intent_part("composure", Pal.BLUE, it.block))
		said.append("gain %d Composure" % it.block)
	if it.has_status():
		var on_player := it.status_target == IntentDef.StatusTarget.PLAYER
		%IntentParts.add_child(_intent_part(it.status, Pal.PURPLE if on_player else Pal.GREEN, it.status_amount))
		said.append("%s %s %d" % ["give you" if on_player else "gain", StatusDefs.display_name(it.status), it.status_amount])
	_tip(%Intent, "Intent: %s" % it.label, "%s will %s." % [duel.enemy_def.name, ", ".join(said)], "taunt")


func _intent_part(icon_name: String, color: Color, n: int) -> Control:
	var row := Ui.hbox(0.15)
	row.add_child(Ui.icon(icon_name, color, 1.3))
	row.add_child(Ui.label(str(n), 1.1))
	return row


func _fill_statuses(box: HBoxContainer, f: Duel.Fighter) -> void:
	for c in box.get_children():
		c.queue_free()
	for id: String in f.statuses:
		var n: int = f.statuses[id]
		var chip := Ui.status_chip(id, n)
		_tip(chip, "%s %d" % [StatusDefs.display_name(id), n], StatusDefs.ALL[id].text.replace("X", str(n)), id)
		box.add_child(chip)


func _block_badge(badge: Control, value: int) -> void:
	badge.visible = value > 0
	(badge.get_node("Value") as Label).text = str(value)


func _fill_slot(slot: PanelContainer, c: CardInstance, i: int) -> void:
	for child in slot.get_children():
		child.queue_free()
	slot.remove_meta("tip")
	var next := duel != null and i == duel.plate.size()
	if c == null:
		var dragging_ing: bool = not _drag.is_empty() and _drag.get("started", false) and _drag.view.card.def.is_ingredient()
		var border := Pal.ORANGE if next and dragging_ing else Color(Pal.INK, 0.33)
		var bg := Color(Pal.ORANGE, 0.12) if next and dragging_ing else Color(Pal.INK, 0.05)
		slot.add_theme_stylebox_override("panel", Ui.box(bg, border, 0.14, 0.55, 0.0))
		var n := Ui.label(str(i + 1), 1.3, Color(Pal.INK, 0.25), HORIZONTAL_ALIGNMENT_CENTER)
		slot.add_child(n)
		return
	var tag := c.def.first_tag()
	slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var tile := Ui.panel(Ui.box(Pal.CREAM, Pal.INK, 0.16, 0.55, 0.15))
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	var col := Ui.vbox(0.15)
	col.add_child(Ui.icon(tag, Pal.tag_color(tag), 2.0))
	var nm := Ui.label(c.def.name, 0.65, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(nm)
	var dots := Ui.hbox(0.15)
	for q in c.def.quality:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2.ONE * Pal.em(0.45)
		dot.add_theme_stylebox_override("panel", Ui.box(Pal.GOLD, Pal.INK, 0.08, 0.3, 0.0))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(dot)
	col.add_child(dots)
	tile.add_child(col)
	slot.add_child(tile)
	_tip(tile, c.def.name, "%s · Quality %d" % [", ".join(c.def.tags), c.def.quality], tag)
	if c.uid == _placed_uid:
		tile.pivot_offset = slot.custom_minimum_size / 2
		tile.scale = Vector2.ONE * 0.6
		create_tween().tween_property(tile, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _style_serve(armed: bool) -> void:
	var b: Button = %ServeButton
	Ui.style_button(b, Pal.GOLD if armed else Pal.RED, Pal.INK if armed else Color.WHITE, 1.05, 1.1, 0.4)
	b.text = ""
	%ServeLabel.text = "Serve x2" if armed else "Serve"
	var fg := Pal.INK if armed else Color.WHITE
	for n in [%ServeLabel, %ServeCost]:
		n.add_theme_color_override("font_color", fg)
	for n in [%ServeIcon, %ServeCostIcon]:
		n.self_modulate = fg
	%ServeContent.modulate.a = 0.45 if b.disabled else 1.0
	_serve_pulse = _pulse(b, armed, _serve_pulse)


func _pulse(node: CanvasItem, on: bool, current: Tween) -> Tween:
	if current and current.is_valid():
		current.kill()
	node.self_modulate = Color.WHITE
	if not on:
		return null
	var tw := create_tween().set_loops()
	tw.tween_property(node, "self_modulate", Color(1.35, 1.35, 1.35), 0.6)
	tw.tween_property(node, "self_modulate", Color.WHITE, 0.6)
	return tw


# ================================================================ hand

func _rebuild_hand(live: bool) -> void:
	for v in _views:
		v.queue_free()
	_views.clear()
	_hover = null
	var n := duel.hand.size()
	var deal := 0
	for i in n:
		var c := duel.hand[i]
		var k := i - (n - 1) / 2.0
		var v: CardView = CARD_VIEW.instantiate()
		%Hand.add_child(v)
		v.setup(c, live and duel.can_play(c.uid).ok, k > 0.5)
		_views.append(v)
	_layout_hand()
	for v in _views:
		if _prev_hand.has(v.card.uid):
			v.go_home(false)
		else:
			v.deal_in(deal * 0.07)
			deal += 1
	_prev_hand = {}
	for c in duel.hand:
		_prev_hand[c.uid] = true


func _layout_hand() -> void:
	var n := _views.size()
	var w := Pal.em(8.4)
	var h := Pal.em(11.8)
	var step := w - Pal.em(1.4)
	var area: Vector2 = %Root.size
	var base_y := area.y + Pal.em(1.6) - h
	for i in n:
		var k := i - (n - 1) / 2.0
		var v := _views[i]
		v.base_y = base_y
		v.home_pos = Vector2(area.x / 2.0 + k * step - w / 2.0, base_y + Pal.em(k * k * 0.3))
		v.home_rot = k * 3.5
		v.z_index = i


func _process(_delta: float) -> void:
	# 3D-following blocks: rival HUD over its head, Prep Board over the prep table.
	%Rival.position = anchors.rival - Vector2(%Rival.size.x / 2.0, %Rival.size.y)
	%Board.position = anchors.board - Vector2(%Board.size.x / 2.0, %Board.size.y)
	_update_hover()


## Hover is polled (not mouse_entered) so a lifted card does not flicker at its bottom edge.
func _update_hover() -> void:
	var target: CardView = null
	if _drag.is_empty() and not _busy and not %Cookbook.visible and not %Overlay.visible:
		var m: Vector2 = _mouse
		var w := Pal.em(8.4)
		var h := Pal.em(11.8)
		var lift := Pal.em(CardView.HOVER_LIFT_EM)
		if _hover and is_instance_valid(_hover):
			var r := Rect2(_hover.home_pos.x - w * 0.1, _hover.base_y - lift - h * 0.2, w * 1.2, h * 1.2 + lift + h)
			if r.has_point(m):
				target = _hover
		if target == null:
			for i in range(_views.size() - 1, -1, -1):
				if Rect2(_views[i].home_pos, Vector2(w, h)).has_point(m):
					target = _views[i]
					break
	if target == _hover:
		return
	if _hover and is_instance_valid(_hover):
		_hover.set_hovered(false)
	_hover = target
	if _hover:
		_hover.set_hovered(true)


# ================================================================ input + drag

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		match key.keycode:
			KEY_E:
				if duel and not %Cookbook.visible:
					duel.end_turn()
			KEY_S:
				if duel and not %Cookbook.visible:
					duel.serve()
			KEY_P:
				pixel_toggled.emit()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _hover and not _busy and duel:
		get_viewport().set_input_as_handled()
		var check := duel.can_play(_hover.card.uid)
		if not check.ok:
			_hover.shake()
			_reject(check.reason)
			return
		var m: Vector2 = _mouse
		_drag = {view = _hover, start = m, started = false, tilt = 0.0, last_x = m.x, off = Vector2.ZERO, ghost = null}


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = (%Root as Control).make_input_local(event).position
	if _drag.is_empty():
		return
	var m := _mouse
	if event is InputEventMouseMotion:
		_drag_move(m)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		_drag_release(m)


func _drag_begin(m: Vector2) -> void:
	var view: CardView = _drag.view
	var center := view.get_transform() * (view.size / 2.0)
	_drag.off = m - center
	var ghost: CardView = CARD_VIEW.instantiate()
	%DragLayer.add_child(ghost)
	ghost.setup(view.card, true, false)
	ghost.pivot_offset = ghost.size / 2.0
	ghost.position = center - ghost.size / 2.0
	ghost.scale = Vector2.ONE * 1.08
	_drag.ghost = ghost
	view.set_hovered(false)
	view.visible = false
	_drag.started = true
	_hide_tip()
	if view.card.def.is_ingredient():
		%Board.add_theme_stylebox_override("panel", _board_style(false, true))
		_refresh_slots()
	else:
		%PlayZone.show()


func _drag_move(m: Vector2) -> void:
	if not _drag.started:
		if m.distance_to(_drag.start) < DRAG_THRESHOLD:
			return
		_drag_begin(m)
	var ghost: CardView = _drag.ghost
	# Tilt follows horizontal speed, eased so it settles when the cursor stops.
	var target := clampf((m.x - _drag.last_x) * 1.2, -18.0, 18.0)
	_drag.tilt += (target - _drag.tilt) * 0.35
	_drag.last_x = m.x
	ghost.position = m - _drag.off - ghost.size / 2.0
	ghost.rotation_degrees = _drag.tilt
	if _drag.view.card.def.is_ingredient():
		%Board.add_theme_stylebox_override("panel", _board_style(_over_board(m), true))
	else:
		_set_play_zone(_in_play_zone(m))


func _drag_release(m: Vector2) -> void:
	var d := _drag
	if not d.started:
		_drag = {}
		_toast("Drag a card to play it")
		return
	var ghost: CardView = d.ghost
	var def: CardDef = d.view.card.def
	var uid: int = d.view.card.uid
	_busy = true
	var tw := create_tween().set_parallel()
	if def.is_ingredient() and _over_board(m):
		# Shrink into the next board slot.
		var slot := _slots[mini(duel.plate.size(), Duel.PLATE_SIZE - 1)]
		var r := slot.get_global_rect()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ghost, "position", r.get_center() - ghost.size / 2.0, 0.2)
		tw.tween_property(ghost, "scale", Vector2.ONE * (r.size.y / ghost.size.y), 0.2)
		tw.tween_property(ghost, "rotation_degrees", 0.0, 0.2)
		tw.chain().tween_callback(_drag_finish.bind(uid, true))
	elif not def.is_ingredient() and _in_play_zone(m):
		# Whoosh toward the rival (attacks, debuffs) or Apis (Composure, draw, Hype).
		var to: Vector2 = anchors.rival if _hits_rival(def) else anchors.player
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(ghost, "position", to - ghost.size / 2.0, 0.24)
		tw.tween_property(ghost, "scale", Vector2.ONE * 0.3, 0.24)
		tw.tween_property(ghost, "rotation_degrees", d.tilt * 2.0, 0.24)
		tw.tween_property(ghost, "modulate:a", 0.0, 0.24)
		tw.chain().tween_callback(_drag_finish.bind(uid, true))
	else:
		var view: CardView = d.view
		var home := view.get_transform() * (view.size / 2.0)
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(ghost, "position", home - ghost.size / 2.0, 0.18)
		tw.tween_property(ghost, "scale", Vector2.ONE, 0.18)
		tw.tween_property(ghost, "rotation_degrees", view.home_rot, 0.18)
		tw.chain().tween_callback(_drag_finish.bind(uid, false))


func _drag_finish(uid: int, play: bool) -> void:
	var d := _drag
	_drag = {}
	_busy = false
	if is_instance_valid(d.ghost):
		d.ghost.queue_free()
	if is_instance_valid(d.view):
		d.view.visible = true
	%Board.add_theme_stylebox_override("panel", _board_style(false, false))
	%PlayZone.hide()
	if play:
		_placed_uid = uid
		_report(duel.play(uid))
	else:
		_refresh_slots()


func _refresh_slots() -> void:
	for i in _slots.size():
		_fill_slot(_slots[i], duel.plate[i] if i < duel.plate.size() else null, i)


func _over_board(m: Vector2) -> bool:
	return %Board.get_global_rect().grow(40).has_point(m)


func _in_play_zone(m: Vector2) -> bool:
	return m.y < %Root.size.y * PLAY_ZONE_FRAC


func _set_play_zone(active: bool) -> void:
	%PlayZoneGlow.color = Color(Pal.GOLD, 0.27 if active else 0.13)
	%PlayZoneLine.color = Pal.ORANGE if active else Color(Pal.ORANGE, 0.53)
	%PlayZoneLabel.modulate.a = 1.0 if active else 0.0


func _hits_rival(def: CardDef) -> bool:
	for e in def.effects:
		if e.kind == EffectDef.Kind.PRESSURE or (e.kind == EffectDef.Kind.STATUS and e.target == EffectDef.Target.ENEMY):
			return true
	return false


func _board_style(hover: bool, dragging: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = Ui.box(Color("#fff6dd") if hover else Color("#fbf3e2ee"),
			Pal.GOLD if hover else (Color(Pal.GOLD, 0.8) if dragging else Pal.INK), 0.32 if hover or dragging else 0.16, 0.9, 0.22)
	s.content_margin_left = Pal.em(0.7)
	s.content_margin_right = Pal.em(0.7)
	s.content_margin_top = Pal.em(0.55)
	s.content_margin_bottom = Pal.em(0.7)
	return s


func _report(result: Dictionary) -> void:
	if not result.ok:
		_reject(result.reason)


func _reject(reason: String) -> void:
	_toast(reason)
	if reason.contains("Heat"):
		var orb: Control = %HeatOrb
		orb.pivot_offset = orb.size / 2.0
		var tw := create_tween()
		tw.tween_property(orb, "scale", Vector2.ONE * 1.2, 0.13)
		tw.parallel().tween_property(orb, "modulate", Color(1.6, 1.6, 1.6), 0.13)
		tw.tween_property(orb, "scale", Vector2.ONE, 0.3)
		tw.parallel().tween_property(orb, "modulate", Color.WHITE, 0.3)


# ================================================================ tooltips

func _tip(c: Control, title: String, text: String, icon_name: String) -> void:
	c.set_meta("tip", [title, text, icon_name])
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_default_cursor_shape = Control.CURSOR_HELP if not c is Button else Control.CURSOR_POINTING_HAND
	if not c.has_meta("tip_wired"):
		c.set_meta("tip_wired", true)
		c.mouse_entered.connect(_show_tip.bind(c))
		c.mouse_exited.connect(func() -> void: if _tip_owner == c: _hide_tip())


func _show_tip(c: Control) -> void:
	if not _drag.is_empty() or not c.has_meta("tip") or not is_instance_valid(c):
		return
	var t: Array = c.get_meta("tip")
	_tip_owner = c
	var tip: Control = %Tooltip
	for child in tip.get_children():
		child.queue_free()
	var box := Ui.tip_box(t[0], t[1], t[2], 15.0)
	tip.add_child(box)
	tip.show()
	box.reset_size()
	var sz := box.get_combined_minimum_size()
	var r := c.get_global_rect()
	var area: Vector2 = %Root.size
	var below := r.position.y < area.y / 2.0
	var x := clampf(r.get_center().x - sz.x / 2.0, 8.0, area.x - sz.x - 8.0)
	var y := r.end.y + 8.0 if below else r.position.y - sz.y - 8.0
	tip.position = Vector2(x, y)


func _hide_tip() -> void:
	_tip_owner = null
	%Tooltip.hide()


# ================================================================ feedback

func _anchor(target: String) -> Vector2:
	return anchors.rival if target == "enemy" else anchors.player


func _toast(text: String) -> void:
	%ToastLabel.text = text
	var t: Control = %Toast
	t.show()
	t.reset_size()
	t.position = Vector2((%Root.size.x - t.size.x) / 2.0, %Root.size.y - Pal.em(11.5) - t.size.y)
	t.modulate.a = 0.0
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast_tw = create_tween()
	_toast_tw.tween_property(t, "modulate:a", 1.0, 0.15)
	_toast_tw.tween_interval(1.25)
	_toast_tw.tween_callback(t.hide)


## Floating number over a chef (damage, block, status). Same timing as the CSS float-up.
func _float(at: Vector2, text: String, color: Color, size_em: float, icon_name := "", delay := 0.0) -> void:
	var row := Ui.hbox(0.15)
	if icon_name != "":
		row.add_child(Ui.icon(icon_name, color, size_em * 0.9))
	row.add_child(Ui.outlined(text, size_em, color, 0.1))
	%Floaters.add_child(row)
	row.reset_size()
	row.pivot_offset = row.size / 2.0
	var p := at + Vector2(randf_range(-20.0, 20.0), 0.0) - row.size / 2.0
	row.position = p + Vector2(0, Pal.em(0.4) * size_em)
	row.scale = Vector2.ONE * 0.6
	row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(row, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(row, "scale", Vector2.ONE * 1.15, 0.16)
	tw.parallel().tween_property(row, "position", p, 0.16)
	tw.tween_property(row, "scale", Vector2.ONE, 0.11)
	tw.tween_property(row, "position", p - Vector2(0, Pal.em(2.2) * size_em), 0.83).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(row, "modulate:a", 0.0, 0.83).set_ease(Tween.EASE_IN)
	tw.tween_callback(row.queue_free)


func _show_dish(recipe: RecipeDef, perfect: bool, signature: bool, burnt: bool) -> void:
	%DishKicker.text = "DISH SERVED" if recipe else "NO RECIPE MATCHED"
	%DishName.text = recipe.name if recipe else "Improvised Dish"
	for c in %DishTags.get_children():
		c.queue_free()
	if perfect:
		%DishTags.add_child(_dish_tag("check", "Perfect Order x%s" % Duel.PERFECT_ORDER_MULT, Pal.GOLD, Pal.INK))
	if signature:
		%DishTags.add_child(_dish_tag("crown", "Signature x2", Pal.GOLD, Pal.INK))
	if burnt:
		%DishTags.add_child(_dish_tag("burnt", "Burnt -50%", Pal.RED, Color.WHITE))
	if recipe and not perfect:
		%DishTags.add_child(_dish_tag("", "Out of order", Color(1, 1, 1, 0.13), Pal.CREAM))
	%DishTags.visible = %DishTags.get_child_count() > 0
	var b: Control = %DishBanner
	b.show()
	b.reset_size()
	var board: Rect2 = %Board.get_global_rect()
	var p := Vector2(board.get_center().x - b.size.x / 2.0, board.position.y - 12.0 - b.size.y)
	b.position = p
	b.pivot_offset = b.size / 2.0
	b.scale = Vector2.ONE * 0.6
	b.modulate.a = 0.0
	if _banner_tw and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_tw.tween_property(b, "modulate:a", 1.0, 0.23)
	_banner_tw.parallel().tween_property(b, "scale", Vector2.ONE * 1.08, 0.23)
	_banner_tw.tween_property(b, "scale", Vector2.ONE, 0.15)
	_banner_tw.tween_interval(1.25)
	_banner_tw.tween_property(b, "modulate:a", 0.0, 0.28)
	_banner_tw.parallel().tween_property(b, "position", p - Vector2(0, Pal.em(1)), 0.28)
	_banner_tw.tween_callback(b.hide)


func _dish_tag(icon_name: String, text: String, bg: Color, fg: Color) -> Control:
	var row := Ui.hbox(0.2)
	if icon_name != "":
		row.add_child(Ui.icon(icon_name, fg, 1.0))
	row.add_child(Ui.label(text, 0.75, fg))
	return Ui.panel(Ui.pad(Ui.box(bg, bg, 0.0, 0.4, 0.0), 0.45, 0.1), row)


## Signature Dish cut-in (GDD §4.5): spinning rays, slammed ink banner, fade out.
func _play_cutin(dish: String) -> void:
	%CutInDish.text = dish
	var c: Control = %CutIn
	c.show()
	c.modulate.a = 1.0
	var area: Vector2 = %Root.size
	(%CutInRays.material as ShaderMaterial).set_shader_parameter("aspect", area.x / area.y)
	var bar: Control = %CutInBar
	bar.reset_size()
	bar.pivot_offset = bar.size / 2.0
	var center := Vector2((area.x - bar.size.x) / 2.0, (area.y - bar.size.y) / 2.0)
	bar.position = center - Vector2(area.x * 1.2, 0)
	bar.scale = Vector2.ONE
	if _cutin_tw and _cutin_tw.is_valid():
		_cutin_tw.kill()
	_cutin_tw = create_tween()
	_cutin_tw.tween_method(func(v: float) -> void:
		(%CutInRays.material as ShaderMaterial).set_shader_parameter("spin", v), 0.0, 25.0, 1.6)
	_cutin_tw.parallel().tween_property(bar, "position", center, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_cutin_tw.parallel().tween_property(bar, "scale", Vector2.ONE * 1.08, 0.32)
	_cutin_tw.parallel().tween_property(bar, "scale", Vector2.ONE, 0.16).set_delay(0.32)
	_cutin_tw.parallel().tween_property(c, "modulate:a", 0.0, 0.32).set_delay(1.28)
	_cutin_tw.tween_callback(c.hide)


func _pop_in(box: Control) -> void:
	box.modulate.a = 0.0
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(box, "modulate:a", 1.0, 0.25)


# ================================================================ Recipe Book

func _book_row(r: RecipeDef) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(Pal.em(0.8)))
	var name_l := Ui.label(r.name, 1.0)
	name_l.custom_minimum_size.x = Pal.em(8)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_l)
	var seq := Ui.hbox(0.25)
	for i in r.requires.size():
		if i > 0:
			seq.add_child(Ui.icon("arrow", Pal.INK_SOFT, 0.8))
		seq.add_child(Ui.req_chip(r.requires[i]))
	row.add_child(seq)
	var eff := Ui.rich("%s [color=%s][font_size=%d]+ Quality[/font_size][/color]" % [Keywords.highlight(r.text),
			Pal.hex(Pal.INK_SOFT), roundi(Pal.em(0.7))], 0.85)
	eff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eff.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(eff)
	var s := Ui.pad(Ui.box(Color(1, 1, 1, 0.53), Color.TRANSPARENT, 0.0, 0.55, 0.0), 0.6, 0.45)
	return Ui.panel(s, row)
