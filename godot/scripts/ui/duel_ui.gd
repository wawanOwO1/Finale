class_name DuelUI
extends CanvasLayer
## Duel HUD (GDD §7.2), the Godot port of the old ui/hud.ts + ui/drag.ts.
## Placement of every block lives in duel_ui.tscn (move them in the 2D editor); this script
## fills them from the Duel state on `changed`, runs the card drag, tooltips and feedback.
##
## Cards are DRAGGED: ingredients onto a Station (solitaire stack), techniques up out of the hand.
## The top card of a station can be dragged onto another station (once per turn).
## Shortcuts: E = End Turn, S = Serve the best station, P = pixel filter.

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
## Paces the turn loop and the rival's steps (GRAND_DESIGN §1). The TurnDirector node in main.tscn;
## main.gd hands it over.
var director: TurnDirector
## Screen positions of the 3D anchors, pushed every frame by main.gd.
var anchors := {rival = Vector2(1400, 300), player = Vector2(600, 400), board = Vector2(300, 400)}

var _views: Array[CardView] = []
var _prev_hand := {}
var _placed_uid := -1
var _hover: CardView
var _drag := {}
var _busy := false
## Round shown by the announcer ("ROUND 2"). Set by main.gd before bind().
var round_number := 1
## One frame per station (PanelContainer); meta "holder" = the stack Control.
var _cols: Array[PanelContainer] = []
var _stations_box: HBoxContainer
## Dragging a station's top card to another station.
var _sdrag := {}
var _announcer: Announcer
var _emote_holder: Control
var _emote: EmoteBubble
var _result_done := false
# Pixel HUD pieces (HudKit), built over the .tscn nodes so their placement stays editable.
var _round_chip: HBoxContainer
var _hype_bar: HudKit.SegmentBar
var _rival_bar: HudKit.SkewBar
var _rival_portrait: HudKit.Diamond
var _player_bar: HudKit.SkewBar
var _player_block: PanelContainer
var _heat_row: HBoxContainer
var _heat_pips: Array[TextureRect] = []
var _heat_text: Label
var _smug_armed := true
var _angry_shown := false
var _hype_pulse: Tween
var _serve_pulse: Tween
var _toast_tw: Tween
var _banner_tw: Tween
var _cutin_tw: Tween
var _tip_owner: Control
## Last mouse position in HUD coordinates (from events, so it also works with pushed input).
var _mouse := Vector2(-1000, -1000)


func _ready() -> void:
	%EndTurn.pressed.connect(_end_turn)
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%PixelButton.pressed.connect(func() -> void: pixel_toggled.emit())
	_build_static()
	for n in [%Cookbook, %Overlay, %Toast, %DishBanner, %CutIn, %PlayZone, %Tooltip]:
		n.hide()
	# Rival emote follows the head; announcer covers everything but the tooltip.
	_emote_holder = Control.new()
	_emote_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Root.add_child(_emote_holder)
	%Root.move_child(_emote_holder, %Floaters.get_index())
	_emote = EmoteBubble.new()
	_emote_holder.add_child(_emote)
	_announcer = Announcer.new()
	%Root.add_child(_announcer)
	%Root.move_child(_announcer, %Tooltip.get_index())


# ================================================================ public API

## Pre-duel Recipe Book (during the duel the Order Tickets give the hints).
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
	_result_done = false
	_smug_armed = true
	_angry_shown = false
	_sdrag = {}
	_emote.clear()
	d.confidence_lost.connect(_emote_on_hit)
	d.signature_served.connect(func(_dish: String) -> void: _emote.pop("shocked"))
	d.turn_started.connect(func(_turn: int) -> void: _emote_on_intent())
	d.duel_ended.connect(_on_duel_ended)
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
	_intro()


## 3 · 2 · 1 · ROUND N · FIGHT! Input is blocked until it ends.
func _intro() -> void:
	_busy = true
	_hide_tip()
	await _announcer.intro(round_number)
	await director.first_turn()
	_busy = false
	_emote_on_intent()


## End Turn (button or E): the Turn Director plays the rival's turn and hands it back.
func _end_turn() -> void:
	if _locked():
		return
	var r := duel.end_turn()
	if not r.ok:
		_reject(r.reason)
		return
	_hide_tip()
	director.rival_turn()


func announcer() -> Announcer:
	return _announcer


## "Hold click or Space to speed up" (SpeedHint in duel_ui.tscn), shown on the rival turn.
func speed_hint() -> Label:
	return %SpeedHint


## Locks card/station input (rival turn, banners). The result sequence also sets it.
func set_busy(on: bool) -> void:
	_busy = on
	if on:
		_hide_tip()


## E3: the rival "thinks" for a moment before each step.
func rival_think(seconds: float) -> void:
	_emote.pop("think")
	await get_tree().create_timer(seconds).timeout


## A rival step was applied: the intent badge pulses (numbers float from the duel's signals).
func rival_act(_action: Dictionary) -> void:
	if _emote.kind == "think":
		_emote.clear()
	var intent: Control = %Intent
	intent.pivot_offset = intent.size / 2.0
	var tw := create_tween()
	tw.tween_property(intent, "scale", Vector2.ONE * 1.25, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(intent, "scale", Vector2.ONE, 0.15)


func _on_duel_ended(winner: String) -> void:
	var won := winner == "player"
	if won:
		_emote.pop("sad")
	else:
		_emote.clear()
		_emote.pop("smug")
	_busy = true
	_hide_tip()
	await get_tree().create_timer(0.7).timeout
	await _announcer.result(won)
	_busy = false
	_result_done = true
	_refresh()


## Rival emotes (ART_DIRECTION §5): smug when Apis is low, shocked by a big hit, angry when beaten down.
func _emote_on_hit(target: String, amount: int, _source: String) -> void:
	if duel == null or duel.over():
		return
	if target == "player":
		var low := duel.player.confidence <= duel.player.max_confidence * 0.3
		if low and _smug_armed:
			_smug_armed = false
			_emote.pop("smug")
		return
	if amount >= 15:
		_emote.pop("shocked")
	if not _angry_shown and duel.enemy.confidence <= duel.enemy.max_confidence * 0.25:
		_angry_shown = true
		var wait := 1.7 if _emote.visible else 0.05
		get_tree().create_timer(wait).timeout.connect(func() -> void:
			if duel and not duel.over():
				_emote.pop("angry", true))


func _emote_on_intent() -> void:
	if duel == null or duel.phase != "player" or _announcer.visible:
		return
	var it := duel.intent()
	if it.has_attack() and duel.pressure_from("enemy", it.attack) >= 10:
		_emote.pop("confident")


func set_pixel_on(on: bool) -> void:
	var b: Button = %PixelButton
	Ui.style_button(b, Pal.INK if on else Pal.CREAM, Pal.CREAM if on else Pal.INK, 1.0, 0.3, 0.3)
	_square_button(b, Pal.INK if on else Pal.CREAM)
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
	# Buttons
	Ui.style_button(%EndTurn, Pal.RED, Color.WHITE, 1.2, 1.3, 0.55)
	_square_button(%EndTurn, Pal.RED)
	%EndTurn.text = "END TURN"
	Ui.style_button(%StartButton, Pal.RED, Color.WHITE, 1.1, 1.6, 0.6)
	Ui.style_button(%RestartButton, Pal.RED, Color.WHITE, 1.1, 1.6, 0.6)
	# Stations replace the old Prep Board row: hide its header, slots and single Serve button.
	for n in [%Board.get_node("VBox/Head"), %Slots, %ServeButton]:
		n.hide()
	%Board.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	%Board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	%Board.get_node("VBox").alignment = BoxContainer.ALIGNMENT_BEGIN
	_stations_box = Ui.hbox(STATION_GAP_EM)
	_stations_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_stations_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	%Board.get_node("VBox").add_child(_stations_box)
	_restyle_hud()
	# Cut-in background
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CUTIN_SHADER
	mat.shader = sh
	%CutInRays.material = mat
	%CutInSfx.add_theme_font_override("font", Ui.italic_font())


## HUD restyle to the canvas kit (ART_DIRECTION §4): square ink boxes with hard shadows,
## ROUND chip, segmented Hype, skewed Confidence bars, diamond portraits and intent, Heat pips.
func _restyle_hud() -> void:
	# Top-left: ROUND chip above the venue name.
	_round_chip = HudKit.chip("ROUND", "1")
	var venue: Control = %Root.get_node("Venue")
	venue.add_child(_round_chip)
	venue.move_child(_round_chip, 0)
	venue.add_theme_constant_override("separation", roundi(Pal.em(0.35)))
	# Hype: square cream plate, segmented bar instead of the rounded track.
	%HypeMeter.add_theme_stylebox_override("panel", Ui.pad(HudKit.box(Pal.CREAM), 0.6, 0.3))
	var track: Control = %HypeMeter.get_node("HBox/HypeTrack")
	track.hide()
	_hype_bar = HudKit.SegmentBar.new(14.5, 1.35)
	track.get_parent().add_child(_hype_bar)
	track.get_parent().move_child(_hype_bar, track.get_index() + 1)
	# Rival: diamond portrait + skewed bar; intent becomes a diamond (built in _fill_intent).
	%Intent.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var hp_row: HBoxContainer = %Rival.get_node("Hp")
	hp_row.get_node("HpBar").hide()
	_rival_portrait = HudKit.Diamond.new(2.6)
	_rival_portrait.add_child(Ui.label("?", 1.0, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER))
	hp_row.add_child(_rival_portrait)
	hp_row.move_child(_rival_portrait, 0)
	_rival_bar = HudKit.SkewBar.new(11.0, 1.35, 0.8)
	hp_row.add_child(_rival_bar)
	hp_row.move_child(_rival_bar, 1)
	hp_row.add_theme_constant_override("separation", roundi(Pal.em(0.5)))
	# Player: diamond portrait over the old heart badge, bar + Composure + Heat pips beside it.
	for c in %HpBadge.get_children():
		c.hide()
	var portrait := HudKit.Diamond.new(6.0)
	portrait.add_child(Ui.label("A", 2.0, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER))
	Ui.fill(portrait)
	%HpBadge.add_child(portrait)
	%PlayerBlock.hide()
	%HeatOrb.hide()
	var col := Ui.vbox(0.35)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_bar = HudKit.SkewBar.new(11.5, 1.75, 1.1)
	_tip(_player_bar, "Confidence", Keywords.BASE.Confidence.text, "confidence")
	_player_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(_player_bar)
	_player_block = HudKit.tag("COMPOSURE 0", Pal.BLUE)
	_player_block.mouse_filter = Control.MOUSE_FILTER_PASS
	_tip(_player_block, "Composure", Keywords.BASE.Composure.text, "composure")
	var block_row := Ui.hbox(0.3)
	block_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	block_row.add_child(_player_block)
	col.add_child(block_row)
	_heat_row = Ui.hbox(0.2)
	_heat_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_heat_row.mouse_filter = Control.MOUSE_FILTER_PASS
	for i in Duel.MAX_HEAT:
		var pip := Ui.icon("heat", Pal.ORANGE, 1.9)
		_heat_row.add_child(pip)
		_heat_pips.append(pip)
	_heat_text = Ui.outlined("HEAT 3/3", 0.75, Pal.CREAM, 0.12)
	_heat_row.add_child(_heat_text)
	_tip(_heat_row, "Heat", Keywords.BASE.Heat.text, "heat")
	col.add_child(_heat_row)
	%HpBadge.get_parent().add_child(col)
	%HpBadge.get_parent().move_child(col, %HpBadge.get_index() + 1)
	%HpBadge.get_parent().add_theme_constant_override("separation", roundi(Pal.em(1.1)))
	# Piles: card backs (draw = blue, discard = paper) with the count on an ink chip.
	%DrawPile.add_theme_stylebox_override("panel", Ui.pad(HudKit.box(Pal.BLUE), 0.5, 0.25))
	%DrawPile.get_node("HBox/Icon").self_modulate = Pal.CREAM
	%DrawCount.add_theme_color_override("font_color", Pal.CREAM)
	%DiscardPile.add_theme_stylebox_override("panel", Ui.pad(HudKit.box(Pal.PAPER), 0.5, 0.25))


## Square pixel look on top of Ui.style_button (keeps its colors and font).
func _square_button(b: Button, bg: Color) -> void:
	var px := Pal.em(0.6)
	var normal := Ui.pad(HudKit.box(bg), px / Pal.EM, 0.3)
	var hover := Ui.pad(HudKit.box(bg.lightened(0.08)), px / Pal.EM, 0.3)
	var pressed := Ui.pad(HudKit.box(bg.darkened(0.05), Pal.INK, 0.18, 0.08), px / Pal.EM, 0.3)
	var disabled := Ui.pad(HudKit.box(Color(bg, 0.45), Color(Pal.INK, 0.45), 0.18, 0.25), px / Pal.EM, 0.3)
	disabled.shadow_color = Color(Pal.INK, 0.45)
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["hover_pressed", pressed]]:
		b.add_theme_stylebox_override(pair[0], pair[1])


func _badge_bg(icon_name: String, color: Color, size_em: float, shadow_em: float) -> Control:
	var bg := Ui.icon_shadowed(icon_name, color, size_em, shadow_em)
	Ui.fill(bg)
	return bg


# ================================================================ render

func _refresh() -> void:
	if duel == null:
		return
	var d := duel
	# live = the player can act. During the rival turn the intent stays up (it is being played).
	var live := d.phase == "player"

	# Rival
	%Intent.visible = not d.over()
	if not d.over():
		_fill_intent(d.intent())
	%RivalName.text = d.enemy_def.name
	%RivalTitle.text = d.enemy_def.title
	%HpFill.anchor_right = float(d.enemy.confidence) / d.enemy.max_confidence
	%HpText.text = "%d / %d" % [d.enemy.confidence, d.enemy.max_confidence]
	_rival_bar.ratio = float(d.enemy.confidence) / d.enemy.max_confidence
	_rival_bar.text_label.text = "%d / %d" % [d.enemy.confidence, d.enemy.max_confidence]
	(_rival_portrait.get_child(0) as Label).text = d.enemy_def.name.left(1)
	(_round_chip.find_child("Value", true, false) as Label).text = str(round_number)
	_block_badge(%EnemyBlock, d.enemy.composure)
	_fill_statuses(%EnemyStatuses, d.enemy)
	%Rival.reset_size()

	# Player
	%PlayerConf.text = str(d.player.confidence)
	%PlayerConfMax.text = "/%d" % d.player.max_confidence
	%PlayerBlock.hide()
	_player_bar.ratio = float(d.player.confidence) / d.player.max_confidence
	_player_bar.stripe = minf(1.0, float(d.player.composure) / d.player.max_confidence)
	_player_bar.text_label.text = "%d/%d" % [d.player.confidence, d.player.max_confidence]
	_player_block.visible = d.player.composure > 0
	(_player_block.get_child(0) as Label).text = "COMPOSURE %d" % d.player.composure
	for i in _heat_pips.size():
		_heat_pips[i].self_modulate = Pal.ORANGE if i < d.player.heat else Pal.INK_SOFT
	_heat_text.text = "HEAT %d/%d" % [d.player.heat, Duel.MAX_HEAT]
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
	_hype_bar.value = d.hype
	_hype_bar.full = full
	_hype_pulse = _pulse(_hype_bar, full, _hype_pulse)

	# Hand
	_rebuild_hand(live)

	# Stations: solitaire stacks with an Order Ticket each (ART_DIRECTION §6).
	_refresh_stations()
	_placed_uid = -1
	%EndTurn.disabled = not live
	if d.player.confidence > d.player.max_confidence * 0.3:
		_smug_armed = true

	# End of duel (after the FINISHED announcer)
	%Overlay.visible = d.over() and _result_done
	if d.over() and _result_done:
		var won := d.phase == "won"
		%ResultTitle.text = "Victory" if won else "Defeat"
		%ResultTitle.add_theme_color_override("font_color", Pal.RED if won else Pal.INK_SOFT)
		%ResultText.text = ("%s gives up in %d turns. Confidence left: %d." % [d.enemy_def.name, d.turn, d.player.confidence]) \
				if won else ("%s out-cooked you this time." % d.enemy_def.name)
		_pop_in(%EndBox)


## Intent (ref 3 #11): a diamond with the main number (red attack, blue block, purple status),
## extra parts as small icons beside it, and the intent name on an ink tag.
func _fill_intent(it: IntentDef) -> void:
	for c in %IntentParts.get_children():
		c.queue_free()
	var main_color := Pal.PURPLE
	var main_value := it.status_amount
	if it.has_attack():
		main_color = Pal.RED
		main_value = duel.pressure_from("enemy", it.attack)
	elif it.block > 0:
		main_color = Pal.BLUE
		main_value = it.block
	var dia := HudKit.Diamond.new(3.0, main_color)
	dia.add_child(Ui.outlined(str(main_value), 1.15, Pal.CREAM, 0.12))
	%IntentParts.add_child(dia)
	var extras := Ui.hbox(0.2)
	%IntentParts.add_child(extras)
	%IntentParts.add_child(HudKit.tag(it.label.to_upper(), Pal.INK, Pal.CREAM, 0.6))
	var said: PackedStringArray = []
	if it.has_attack():
		var v := duel.pressure_from("enemy", it.attack)
		extras.add_child(Ui.icon("pressure", Pal.RED, 1.1))
		said.append("deal %d Pressure" % v)
	if it.block > 0:
		extras.add_child(_intent_part("composure", Pal.BLUE, it.block) if it.has_attack() else Ui.icon("composure", Pal.BLUE, 1.1))
		said.append("gain %d Composure" % it.block)
	if it.has_status():
		var on_player := it.status_target == IntentDef.StatusTarget.PLAYER
		extras.add_child(_intent_part(it.status, Pal.PURPLE if on_player else Pal.GREEN, it.status_amount))
		said.append("%s %s %d" % ["give you" if on_player else "gain", StatusDefs.display_name(it.status), it.status_amount])
	_tip(%Intent, "Intent: %s" % it.label, "%s will %s." % [duel.enemy_def.name, ", ".join(said)], "taunt")


func _intent_part(icon_name: String, color: Color, n: int) -> Control:
	var row := Ui.hbox(0.1)
	row.add_child(Ui.icon(icon_name, color, 1.1))
	row.add_child(Ui.outlined(str(n), 0.85, Pal.CREAM, 0.1))
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


# ================================================================ stations

const STATION_GAP_EM := 0.9
## Top of the stations, above the prep-table anchor.
const STATION_TOP_EM := 10.5
const CARD_W_EM := 7.4
const CARD_H_EM := 6.4
## Visible strip of a covered card (name + tag icon).
const BAND_EM := 1.75
## Light tag colors get ink text, dark ones cream.
const DARK_TAGS: PackedStringArray = ["VEGGIE", "SPICE", "SAUCE"]


func _refresh_stations() -> void:
	for c in _cols:
		c.queue_free()
	_cols.clear()
	for i in Duel.STATIONS:
		var frame := _station_column(i)
		_stations_box.add_child(frame)
		_cols.append(frame)
	_highlight_stations(-1)


func _station_column(i: int) -> PanelContainer:
	var d := duel
	var st := d.stack(i)
	var tk := d.ticket(i)
	var col := Ui.vbox(0.35)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.custom_minimum_size.x = Pal.em(CARD_W_EM)
	col.add_child(_ticket_view(i, tk))

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := st.size()
	holder.custom_minimum_size = Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM) + Pal.em(BAND_EM) * maxi(n - 1, 0))
	if n == 0:
		var ph := Ui.panel(Ui.box(Color(Pal.CREAM, 0.12), Color(Pal.CREAM, 0.55), 0.14, 0.7, 0.0),
				Ui.label("+  Station %d" % (i + 1), 0.8, Color(Pal.CREAM, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
		ph.position = Vector2.ZERO
		ph.size = Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM))
		holder.add_child(ph)
	for k in n:
		var card := _stack_card(st[k], k == n - 1)
		card.position = Vector2(0, Pal.em(BAND_EM) * k)
		card.size = Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM))
		holder.add_child(card)
		if st[k].uid == _placed_uid:
			card.pivot_offset = card.size / 2.0
			card.scale = Vector2.ONE * 0.6
			create_tween().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	col.add_child(holder)

	if n > 0 and d.phase == "player":
		var row := Ui.hbox(0.3)
		var serve := Button.new()
		var armed := d.signature_armed
		serve.text = "Serve x2" if armed else "Serve"
		Ui.style_button(serve, Pal.GOLD if armed else Pal.RED, Pal.INK if armed else Color.WHITE, 0.9, 0.8, 0.4)
		serve.disabled = not d.can_serve(i).ok
		serve.pressed.connect(func() -> void: _serve(i))
		_tip(serve, "Serve", Keywords.BASE.Serve.text, "serve")
		row.add_child(serve)
		var clear := Button.new()
		clear.text = "Clear"
		Ui.style_button(clear, Pal.INK_SOFT, Pal.CREAM, 0.75, 0.5, 0.4)
		clear.disabled = d.moved_this_turn
		clear.pressed.connect(func() -> void: if not _locked(): _report(duel.clear_station(i)))
		_tip(clear, "Clear station", "Throw this whole stack into the discard pile. Free, but uses your one move this turn.", "discard")
		row.add_child(clear)
		col.add_child(row)

	var frame := Ui.panel(Ui.pad(StyleBoxEmpty.new(), 0.25, 0.25), col)
	frame.set_meta("holder", holder)
	frame.set_meta("station", i)
	return frame


## Order Ticket (ref 7): dish name, its steps as tag chips (done / next / todo), state line.
func _ticket_view(i: int, tk: Dictionary) -> Control:
	var state: String = tk.state
	var recipe: RecipeDef = tk.recipe
	var vb := Ui.vbox(0.2)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	var head := Ui.hbox(0.3)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	var title := "Station %d" % (i + 1)
	if recipe:
		title = recipe.name
	elif state == "improvised":
		title = "???"
	var name_l := Ui.label(title, 0.85, Pal.INK if state != "empty" else Pal.INK_SOFT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	head.add_child(name_l)
	if state == "perfect" or state == "cooked":
		var stamp_bg := Pal.GOLD if state == "perfect" else Pal.PAPER
		var stamp := Ui.panel(Ui.pad(Ui.box(stamp_bg, Pal.INK, 0.1, 0.2, 0.0), 0.25, 0.0),
				Ui.label("PERFECT!" if state == "perfect" else "COOKED", 0.55))
		stamp.rotation_degrees = 8.0
		head.add_child(stamp)
	vb.add_child(head)

	var steps := Ui.hbox(0.15)
	steps.alignment = BoxContainer.ALIGNMENT_BEGIN
	for s: Dictionary in tk.steps:
		steps.add_child(_step_chip(s.req, s.state))
	if tk.steps.is_empty():
		steps.custom_minimum_size.y = Pal.em(1.3)
	vb.add_child(steps)

	var line := ""
	match state:
		"empty":
			line = "Drop an ingredient"
		"building":
			line = "Next: %s" % _req_name(tk.steps[mini(duel.stack(i).size(), tk.steps.size() - 1)].req)
		"perfect":
			line = "Perfect order x%s" % Duel.PERFECT_ORDER_MULT
		"cooked":
			line = "Out of order x1"
		"improvised":
			line = "No recipe: %d Pressure" % (2 * duel.stack(i).size())
	if tk.garnish > 0:
		line += " · +%d Garnish" % tk.garnish
	vb.add_child(Ui.label(line, 0.6, Pal.INK_SOFT))

	var bg := Pal.PAPER if state == "improvised" else Pal.CREAM
	var border := Pal.GOLD if state == "perfect" else Pal.INK
	var p := Ui.panel(Ui.pad(Ui.box(bg, border, 0.2 if state == "perfect" else 0.13, 0.3, 0.15), 0.45, 0.3), vb)
	p.custom_minimum_size.x = Pal.em(CARD_W_EM)
	if recipe:
		var seq: PackedStringArray = []
		for r in recipe.requires:
			seq.append(_req_name(r))
		_tip(p, recipe.name, "%s.\nOrder: %s." % [recipe.text, " > ".join(seq)], "book")
	if state == "empty":
		p.modulate.a = 0.75
	return p


func _req_name(req: String) -> String:
	if req.begins_with("card:"):
		var def := GameDB.card(req.substr(5))
		return def.name if def else req
	return req.capitalize()


func _req_tag(req: String) -> String:
	if req.begins_with("card:"):
		var def := GameDB.card(req.substr(5))
		return def.first_tag() if def else ""
	return req


func _step_chip(req: String, state: String) -> Control:
	var tag := _req_tag(req)
	var done := state == "done"
	var bg := Pal.tag_color(tag) if done else Pal.CREAM
	var border := Pal.ORANGE if state == "next" else Pal.INK
	var fg := (Pal.CREAM if tag in DARK_TAGS else Pal.INK) if done else Pal.tag_color(tag)
	var chip := Ui.panel(Ui.pad(Ui.box(bg, border, 0.16 if state == "next" else 0.1, 0.25, 0.0), 0.12, 0.08), Ui.icon(tag, fg, 0.95))
	if state == "todo":
		chip.modulate.a = 0.4
	elif state == "next":
		var tw := chip.create_tween().set_loops()
		tw.tween_property(chip, "modulate:a", 0.45, 0.5)
		tw.tween_property(chip, "modulate:a", 1.0, 0.5)
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	_tip(chip, _req_name(req), "Recipe step: %s (%s)." % [_req_name(req), state], tag)
	return chip


## One card in a station. Covered cards show only the band (name + tag icon); the top card is
## fully open with a gold frame (it is the one you can drag to another station).
func _stack_card(c: CardInstance, top: bool) -> PanelContainer:
	var tag := c.def.first_tag()
	var bg := Pal.tag_color(tag)
	var fg := Pal.CREAM if tag in DARK_TAGS else Pal.INK
	var s := Ui.box(bg, Pal.GOLD if top else Pal.INK, 0.16 if top else 0.12, 0.55, 0.0)
	s.content_margin_left = Pal.em(0.45)
	s.content_margin_right = Pal.em(0.45)
	s.content_margin_top = Pal.em(0.2)
	s.content_margin_bottom = Pal.em(0.3)
	var vb := Ui.vbox(0.15)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	var band := Ui.hbox(0.2)
	var nm := Ui.label(c.def.name, 0.8, fg)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	band.add_child(nm)
	band.add_child(Ui.icon(tag, fg, 0.9))
	vb.add_child(band)
	if top:
		vb.add_child(Ui.icon(tag, Color(fg, 0.85), 2.6))
		var dots := Ui.hbox(0.15)
		for q in c.def.quality:
			var dot := Panel.new()
			dot.custom_minimum_size = Vector2.ONE * Pal.em(0.45)
			dot.add_theme_stylebox_override("panel", Ui.box(Pal.GOLD, Pal.INK, 0.08, 0.3, 0.0))
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dots.add_child(dot)
		vb.add_child(dots)
	var p := Ui.panel(s, vb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	_tip(p, c.def.name, "%s · Quality %d%s" % [", ".join(c.def.tags), c.def.quality,
			"\nDrag onto another station to move it (once per turn)." if top else ""], tag)
	return p


## Station under the cursor, or -1.
func _station_at(m: Vector2) -> int:
	for i in _cols.size():
		if is_instance_valid(_cols[i]) and _cols[i].get_global_rect().grow(Pal.em(0.6)).has_point(m):
			return i
	return -1


## Where the next card of a station lands (global rect).
func _next_card_rect(i: int) -> Rect2:
	var holder: Control = _cols[i].get_meta("holder")
	var n := duel.stack(i).size()
	var r := holder.get_global_rect()
	return Rect2(r.position + Vector2(0, Pal.em(BAND_EM) * n), Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM)))


## Top card of a station (global rect), or an empty Rect2.
func _top_card_rect(i: int) -> Rect2:
	var n := duel.stack(i).size()
	if n == 0 or i >= _cols.size() or not is_instance_valid(_cols[i]):
		return Rect2()
	var holder: Control = _cols[i].get_meta("holder")
	var r := holder.get_global_rect()
	return Rect2(r.position + Vector2(0, Pal.em(BAND_EM) * (n - 1)), Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM)))


## While dragging an ingredient: gold = continues a recipe (or empty), orange = off path, grey = full.
## `over` is the station under the cursor (stronger highlight).
func _highlight_stations(over: int, card: CardInstance = null) -> void:
	for i in _cols.size():
		var frame := _cols[i]
		if not is_instance_valid(frame):
			continue
		if card == null:
			frame.add_theme_stylebox_override("panel", Ui.pad(StyleBoxEmpty.new(), 0.25, 0.25))
			continue
		var st := duel.stack(i)
		var color := Pal.GOLD
		if st.size() >= Duel.STATION_SIZE:
			color = Color(Pal.INK, 0.5)
		elif not st.is_empty() and not RecipeMatch.accepts_next(duel.recipes, st, card):
			color = Pal.ORANGE
		var on := i == over
		var s := Ui.box(Color(color, 0.28 if on else 0.1), Color(color, 1.0 if on else 0.6), 0.2 if on else 0.12, 0.7, 0.0)
		frame.add_theme_stylebox_override("panel", Ui.pad(s, 0.25, 0.25))


func _serve(i: int) -> void:
	if _locked():
		return
	_report(duel.serve(i))


## S key: a finished dish first (Perfect, then Cooked), else the biggest stack.
func _best_station() -> int:
	var best := -1
	var best_key := [-1, -1]
	for i in Duel.STATIONS:
		if not duel.can_serve(i).ok:
			continue
		var tk := duel.ticket(i)
		var rank: int = {perfect = 3, cooked = 2}.get(tk.state, 0)
		var key := [rank, duel.stack(i).size()]
		if key[0] > best_key[0] or (key[0] == best_key[0] and key[1] > best_key[1]):
			best_key = key
			best = i
	return best


## Input is ignored while the announcer or a drag animation runs.
func _locked() -> bool:
	return duel == null or _busy or %Cookbook.visible or _announcer.visible


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
	# 3D-following blocks: rival HUD over its head, stations hang down from above the prep table
	# (stacks grow downward like solitaire), emote bubble beside the rival's head.
	%Rival.position = anchors.rival - Vector2(%Rival.size.x / 2.0, %Rival.size.y)
	%Board.reset_size()
	%Board.position = Vector2(anchors.board.x - %Board.size.x / 2.0, anchors.board.y - Pal.em(STATION_TOP_EM))
	_emote_holder.position = anchors.rival + Vector2(Pal.em(2.6), Pal.em(0.9))
	_update_hover()


## Hover is polled (not mouse_entered) so a lifted card does not flicker at its bottom edge.
func _update_hover() -> void:
	var target: CardView = null
	if _drag.is_empty() and _sdrag.is_empty() and not _busy and not %Cookbook.visible and not %Overlay.visible and not _announcer.visible:
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
				_end_turn()
			KEY_S:
				if not _locked():
					var best := _best_station()
					if best >= 0:
						_serve(best)
					else:
						_reject("Nothing to serve.")
			KEY_P:
				pixel_toggled.emit()
		return
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _hover and not _locked():
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
	if _station_drag_input(event):
		return
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
		_highlight_stations(-1, view.card)
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
		_highlight_stations(_station_at(m), _drag.view.card)
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
	var target := _station_at(m) if def.is_ingredient() else -1
	if target >= 0 and duel.can_play(uid, target).ok:
		# Shrink onto the station's next card spot.
		var r := _next_card_rect(target)
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(ghost, "position", r.get_center() - ghost.size / 2.0, 0.2)
		tw.tween_property(ghost, "scale", Vector2.ONE * (r.size.x / ghost.size.x), 0.2)
		tw.tween_property(ghost, "rotation_degrees", 0.0, 0.2)
		tw.chain().tween_callback(_drag_finish.bind(uid, true, target))
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
		if target >= 0:
			_reject(duel.can_play(uid, target).reason)


func _drag_finish(uid: int, play: bool, station := -1) -> void:
	var d := _drag
	_drag = {}
	_busy = false
	if is_instance_valid(d.ghost):
		d.ghost.queue_free()
	if is_instance_valid(d.view):
		d.view.visible = true
	%PlayZone.hide()
	_highlight_stations(-1)
	if play:
		_placed_uid = uid
		_report(duel.play(uid, station))


## Drag the top card of a station onto another one (Duel.move_top). Returns true when the
## event was used. Runs in _input so it wins over the tooltip controls on the cards.
func _station_drag_input(event: InputEvent) -> bool:
	var m := _mouse
	var mb := event as InputEventMouseButton
	if _sdrag.is_empty():
		if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed or _locked() or not _drag.is_empty():
			return false
		for i in Duel.STATIONS:
			if _top_card_rect(i).has_point(m):
				get_viewport().set_input_as_handled()
				_sdrag = {from = i, start = m, started = false, ghost = null, off = Vector2.ZERO}
				return true
		return false
	if event is InputEventMouseMotion:
		if not _sdrag.started:
			if m.distance_to(_sdrag.start) < DRAG_THRESHOLD:
				return true
			if duel.moved_this_turn:
				_reject("Already moved a card this turn.")
				_sdrag = {}
				return true
			var r := _top_card_rect(_sdrag.from)
			var ghost := _stack_card(duel.stack(_sdrag.from).back(), true)
			%DragLayer.add_child(ghost)
			ghost.size = r.size
			ghost.position = r.position
			ghost.rotation_degrees = 3.0
			_sdrag.off = m - r.position
			_sdrag.ghost = ghost
			_sdrag.started = true
			_hide_tip()
			var holder: Control = _cols[_sdrag.from].get_meta("holder")
			holder.get_child(-1).modulate.a = 0.25
		_sdrag.ghost.position = m - _sdrag.off
		var over := _station_at(m)
		for i in _cols.size():
			var on: bool = i == over and i != _sdrag.from
			var s := Ui.box(Color(Pal.BLUE, 0.25 if on else 0.0), Color(Pal.BLUE, 1.0 if on else 0.0), 0.2, 0.7, 0.0)
			_cols[i].add_theme_stylebox_override("panel", Ui.pad(s, 0.25, 0.25))
		return true
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		get_viewport().set_input_as_handled()
		var d := _sdrag
		_sdrag = {}
		if is_instance_valid(d.ghost):
			d.ghost.queue_free()
		if d.started:
			var to := _station_at(m)
			if to >= 0 and to != d.from:
				_report(duel.move_top(d.from, to))
				return true
			_refresh()
		return true
	return false


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


func _report(result: Dictionary) -> void:
	if not result.ok:
		_reject(result.reason)


func _reject(reason: String) -> void:
	_toast(reason)
	if reason.contains("Heat"):
		var orb: Control = _heat_row
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
	var si := duel.last_served_station if duel else -1
	if si >= 0 and si < _cols.size() and is_instance_valid(_cols[si]):
		board = _cols[si].get_global_rect()
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
