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
## Set by main.gd: the discoveries the Almanac window shows (GRAND_DESIGN §6).
var almanac_keeper: AlmanacKeeper
## Tab was pressed on the rival turn: open the Almanac as soon as it is the player's turn.
var _almanac_queued := false
## Screen positions of the 3D anchors, pushed every frame by main.gd.
var anchors := {rival = Vector2(1400, 300), player = Vector2(600, 400), board = Vector2(300, 400),
		rival_stations = Vector2(1300, 420)}

@export_group("Hand")
## Card size in hand (1 = the card_view.tscn size). Hover grows it a little more.
@export_range(0.5, 3.0, 0.05) var hand_card_scale := 1.9
## How much neighbouring cards overlap, as a share of the card width.
@export_range(0.0, 0.6, 0.01) var hand_overlap := 0.12
## The whole hand may be at most this share of the screen width.
@export_range(0.3, 1.0, 0.01) var hand_max_width := 0.6
## How far the cards sink below the bottom edge (em, before scaling).
@export var hand_sink_em := 0.8
## Moves the hand right of center (em) so it clears the player panel and draw pile.
@export var hand_offset_em := 1.0
@export_group("Stations")
## Both Stations panels (Apis left, rival right) share this layout, in UI pixels (1920x1080 base).
## Size of the cards and stacks inside the panels (1 = as laid out in code).
@export_range(0.5, 2.5, 0.05) var board_scale := 1.4
## Gap between each panel and its screen edge.
@export var stations_margin_px := 29.0
## Top of both panels (their tab sits above this).
@export var stations_top_px := 278.0
## Smallest panel size; a tall stack can still grow it downward.
@export var stations_size_px := Vector2(432, 560)
## Space kept above each Stations panel for its tab when the panel above it grows.
@export var stations_tab_room_px := 52.0
@export_group("")

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
## Dragging a station's top card to another station.
var _sdrag := {}
var _announcer: Announcer
var _emote_holder: Control
var _emote: EmoteBubble
var _result_done := false
## Recipe Book page shown (index into _book_recipes).
var _book_recipes: Array[RecipeDef] = []
var _book_page := 0
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
	%AlmanacButton.pressed.connect(toggle_almanac)
	%BookAlmanac.pressed.connect(toggle_almanac)
	%Almanac.closed.connect(_refresh_almanac_dot)
	_build_static()
	for n in [%Cookbook, %Overlay, %Toast, %DishBanner, %CutIn, %PlayZone, %Tooltip, %FlowPick]:
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

## Pre-duel Recipe Book (Recipe Book v2 board): one recipe per spread, dish on the left page,
## cooking order on the right, chapter ribbons per book. During the duel the Order Tickets hint.
## Await it: `await ui.show_cookbook(recipes)`.
func show_cookbook(recipes: Array[RecipeDef]) -> void:
	%Overlay.hide()
	_book_recipes = recipes
	_build_ribbons()
	_show_book_page(0)
	%Cookbook.show()
	_pop_in(%BookBox)
	_refresh_almanac_dot()
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
	d.signature_served.connect(func(side: String, _dish: String) -> void: if side == "player": _emote.pop("shocked"))
	d.turn_started.connect(func(_turn: int) -> void: _emote_on_intent())
	d.duel_ended.connect(_on_duel_ended)
	%VenueSub.text = "vs %s" % d.enemy_def.name
	d.changed.connect(_refresh)
	d.signature_served.connect(_play_cutin)
	d.dish_revealed.connect(_show_dish)
	d.mise_en_place.connect(func(side: String, _drawn: CardInstance, _given: CardInstance) -> void: show_mise(side))
	d.flow_offer.connect(_on_flow_offer)
	d.modifier_gained.connect(_on_modifier_gained)
	%FlowPick.hide()
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


## A rival step was applied (GRAND_DESIGN §1.3). Numbers, statuses and the dish reveal float up
## from the duel's own signals; this adds what the step itself looks like, never the card face.
func rival_act(action: Dictionary) -> void:
	if _emote.kind == "think":
		_emote.clear()
	match action.get("kind", ""):
		"place":
			# The new face-down card drops onto its station.
			var back: Control = _rival_tops.get(action.station)
			if back:
				back.pivot_offset = back.size / 2.0
				back.position.y -= Pal.em(1.2)
				back.scale = Vector2.ONE * 1.3
				var tw := create_tween().set_parallel()
				tw.tween_property(back, "position:y", back.position.y + Pal.em(1.2), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(back, "scale", Vector2.ONE, 0.22)
		"technique":
			_float(anchors.rival + Vector2(0, -Pal.em(1.5)), "Technique!", Pal.CREAM, 1.0, "technique")
		"serve":
			pass
		_:
			# Old intent-pattern rival: its intent badge pulses.
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


## On Apis's turn the rival shows a mood instead of an intent (GRAND_DESIGN §3.4): vague on
## purpose. A drafting rival: Confident = a big dish is ready on its counter, Wary = it is low.
func _emote_on_intent() -> void:
	if duel == null or duel.phase != "player" or _announcer.visible:
		return
	if duel.drafting():
		var m := RivalAI.mood(duel)
		if m != "":
			_emote.pop(m)
		return
	var it := duel.intent()
	if it and it.has_attack() and duel.pressure_from("enemy", it.attack) >= 10:
		_emote.pop("confident")


func set_pixel_on(on: bool) -> void:
	var b: Button = %PixelButton
	Ui.style_button(b, Pal.HUD_PANEL, Pal.CREAM, 1.0, 0.3, 0.3)
	_square_button(b, Pal.GOLD.darkened(0.35) if on else Pal.HUD_PANEL)
	%PixelIcon.self_modulate = Pal.GOLD if on else Pal.CREAM
# ================================================================ static build

func _build_static() -> void:
	# Top bar
	_tip(%Hype, "Hype", Keywords.BASE.Hype.text, "hype")
	_tip(%PixelButton, "Pixel filter", "Toggle the low-res pixel look. Shortcut: P.", "pixel")
	Ui.style_button(%AlmanacButton, Pal.HUD_PANEL, Pal.CREAM, 1.0, 0.3, 0.3)
	_square_button(%AlmanacButton, Pal.HUD_PANEL)
	%AlmanacButton.get_node("AlmanacIcon").self_modulate = Pal.CREAM
	_tip(%AlmanacButton, "Almanac", "Everything you have discovered: ingredients, techniques, recipes and rivals. Pauses the duel. Shortcut: Tab.", "book")
	Ui.style_button(%BookAlmanac, Pal.PAPER, Pal.INK, 1.4, 1.2, 0.5)
	_square_button(%BookAlmanac, Pal.PAPER)
	set_pixel_on(false)
	_tip(%PlayerHp, "Confidence", Keywords.BASE.Confidence.text + "\nBlue cap: Composure.", "confidence")
	_tip(%RivalHp, "Confidence", Keywords.BASE.Confidence.text + "\nBlue cap: Composure.", "confidence")
	_tip(%HeatRow, "Heat", Keywords.BASE.Heat.text, "heat")
	_tip(%DrawPile, "Draw pile", "Cards you will draw. Shuffled from the discard pile when empty.", "draw")
	_tip(%DiscardPile, "Discard pile", "Played and discarded cards. Shuffled back when the draw pile runs out.", "discard")
	# Piles: blue chip for draw, dark chip for discard (HUD v2).
	%DrawPile.add_theme_stylebox_override("panel", Ui.pad(HudKit.box(Pal.BLUE, Pal.HUD_INK, 0.2, 0.3), 0.5, 0.25))
	%DrawPile.get_node("HBox/Icon").self_modulate = Pal.CREAM
	%DrawCount.add_theme_color_override("font_color", Pal.CREAM)
	%RivalDrawPile.add_theme_stylebox_override("panel", Ui.pad(HudKit.box(Pal.RED_DARK, Pal.HUD_INK, 0.2, 0.3), 0.5, 0.25))
	_tip(%RivalDrawPile, "Rival draw pile", "Cards the rival has left to draw.", "draw")
	%DiscardPile.add_theme_stylebox_override("panel", Ui.pad(HudKit.box(Pal.HUD_PANEL, Pal.HUD_INK, 0.2, 0.3), 0.5, 0.2))
	%DiscardPile.get_node("HBox/Icon").self_modulate = Pal.HUD_MUTED
	%DiscardCount.add_theme_color_override("font_color", Pal.CREAM)
	# Buttons
	Ui.style_button(%EndTurn, Pal.RED, Pal.CREAM, 2.2, 1.0, 0.4)
	HudKit.style_red_button(%EndTurn)
	%EndTurn.text = "END TURN"
	Ui.style_button(%StartButton, Pal.RED, Pal.CREAM, 1.75, 1.6, 0.5)
	HudKit.style_red_button(%StartButton)
	for b: Button in [%PrevPage, %NextPage]:
		Ui.style_button(b, Pal.INK_SOFT, Pal.CREAM, 1.2, 0.5, 0.1)
		_square_button(b, Pal.INK_SOFT)
	%PrevPage.pressed.connect(func() -> void: _show_book_page(_book_page - 1))
	%NextPage.pressed.connect(func() -> void: _show_book_page(_book_page + 1))
	Ui.style_button(%RestartButton, Pal.RED, Color.WHITE, 1.1, 1.6, 0.6)
	# Cut-in background
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = CUTIN_SHADER
	mat.shader = sh
	%CutInRays.material = mat
	%CutInSfx.add_theme_font_override("font", Ui.italic_font())

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



# ================================================================ render

func _refresh() -> void:
	if duel == null:
		return
	_refresh_almanac_dot()
	var d := duel
	# live = the player can act. During the rival turn the intent stays up (it is being played).
	var live := d.phase == "player"

	# Rival panel (top-right)
	# Old pattern rivals show their intent; a drafting rival shows face-down stations instead.
	%Intent.visible = not d.over() and not d.drafting()
	if %Intent.visible:
		_fill_intent(d.intent())
	%RivalKitchen.visible = d.drafting()
	%RivalInfo.visible = d.drafting()
	%RivalDrawPile.visible = d.drafting()
	if d.drafting():
		_refresh_rival_kitchen()
	%RivalName.text = d.enemy_def.name
	%RivalTitle.text = d.enemy_def.title
	%RivalHp.ratio = float(d.enemy.confidence) / d.enemy.max_confidence
	%RivalHp.shield = d.enemy.composure
	%RivalHp.text = "%d/%d" % [d.enemy.confidence, d.enemy.max_confidence]
	%RoundLabel.text = "ROUND %d" % round_number
	_fill_statuses(%EnemyStatuses, d.enemy)
	%EnemyFlow.visible = d.drafting()
	_fill_flow(%EnemyFlow, "enemy")

	# Player
	%PlayerHp.ratio = float(d.player.confidence) / d.player.max_confidence
	%PlayerHp.shield = d.player.composure
	%PlayerHp.text = "%d/%d" % [d.player.confidence, d.player.max_confidence]
	var pips := %HeatRow.get_children().filter(func(n: Node) -> bool: return n is TextureRect)
	for i in pips.size():
		pips[i].self_modulate = Pal.ORANGE if i < d.player.heat else Pal.HUD_EMPTY
	%HeatText.text = "HEAT %d/%d" % [d.player.heat, Duel.MAX_HEAT]
	_fill_statuses(%PlayerStatuses, d.player)
	_fill_flow(%PlayerFlow, "player")
	%DrawCount.text = str(d.draw_pile.size())
	%DiscardCount.text = str(d.discard.size())

	# Hype
	var full := d.hype >= Duel.MAX_HYPE or d.signature_armed
	%HypeBar.max_value = Duel.MAX_HYPE
	%HypeBar.value = d.hype
	%HypeBar.full = full
	_hype_pulse = _pulse(%HypeBar, full, _hype_pulse)

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


## Intent (HUD v2): a big diamond with the main number (red attack, blue block, purple status),
## the intent name in gold beside it and the extra parts as small icons under the name.
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
	%IntentDiamond.fill = main_color
	%IntentValue.text = str(main_value)
	%IntentName.text = it.label.to_upper()
	var said: PackedStringArray = []
	# The diamond shows the main number; the parts row lists only the extras beside it.
	if it.has_attack():
		var v := duel.pressure_from("enemy", it.attack)
		%IntentParts.add_child(Ui.icon("pressure", Pal.RED, 1.3))
		said.append("deal %d Pressure" % v)
	if it.block > 0:
		%IntentParts.add_child(_intent_part("composure", Pal.BLUE, it.block) if it.has_attack() else Ui.icon("composure", Pal.BLUE, 1.3))
		said.append("gain %d Composure" % it.block)
	if it.has_status():
		var on_player := it.status_target == IntentDef.StatusTarget.PLAYER
		%IntentParts.add_child(_intent_part(it.status, Pal.PURPLE if on_player else Pal.GREEN, it.status_amount))
		said.append("%s %s %d" % ["give you" if on_player else "gain", StatusDefs.display_name(it.status), it.status_amount])
	_tip(%Intent, "Intent: %s" % it.label, "%s will %s." % [duel.enemy_def.name, ", ".join(said)], "taunt")
func _intent_part(icon_name: String, color: Color, n: int) -> Control:
	var row := Ui.hbox(0.1)
	row.add_child(Ui.icon(icon_name, color, 1.3))
	row.add_child(Ui.outlined(str(n), 1.0, Pal.CREAM, 0.1))
	return row


func _fill_statuses(box: HBoxContainer, f: Duel.Fighter) -> void:
	for c in box.get_children():
		c.queue_free()
	for id: String in f.statuses:
		var n: int = f.statuses[id]
		var chip := Ui.status_chip(id, n)
		_tip(chip, "%s %d" % [StatusDefs.display_name(id), n], StatusDefs.ALL[id].text.replace("X", str(n)), id)
		box.add_child(chip)



# ================================================================ stations

const STATION_GAP_EM := 0.9
const CARD_W_EM := 7.4
const CARD_H_EM := 6.4
## Visible strip of a covered card (name + tag icon).
const BAND_EM := 1.75
## Rival face-down stations (card backs fanned down like the player's stacks).
const RIVAL_BACK_W_EM := 4.9
const RIVAL_BACK_H_EM := 6.6
const RIVAL_BACK_STEP_EM := 1.15
## Top face-down card of each rival station (for the drop animation).
var _rival_tops := {}
## Light tag colors get ink text, dark ones cream.
const DARK_TAGS: PackedStringArray = ["VEGGIE", "SPICE", "SAUCE"]
## Recipe Book chapter ribbon colors (Recipe Book v2 board).
const BOOK_COLORS := {basics = Color("#3f7fae"), grill = Color("#d9a42a"), spice = Color("#d8342c"), comfort = Color("#2f8a86")}


## The rival's side, face down (GRAND_DESIGN §3.5): how many cards sit on each station and in
## its hand, and its Heat. Never which cards: the dish shows only when it is served.
func _refresh_rival_kitchen() -> void:
	var k := duel.kitchen("enemy")
	for c in %RivalStations.get_children():
		%RivalStations.remove_child(c)
		c.queue_free()
	_rival_tops.clear()
	var right := _grid_right_column()
	for i in Duel.STATIONS:
		var n := k.stack(i).size()
		var col := Ui.vbox(0.35)
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.custom_minimum_size.x = Pal.em(CARD_W_EM)
		col.add_child(Ui.label("Station %d" % (i + 1), 0.85, Pal.HUD_MUTED))
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(Pal.em(CARD_W_EM), Pal.em(RIVAL_BACK_H_EM) + Pal.em(RIVAL_BACK_STEP_EM) * maxi(n - 1, 0))
		if n == 0:
			var ph := HudKit.Dashed.new()
			ph.add_child(Ui.label("Empty", 0.8, Pal.HUD_DASH, HORIZONTAL_ALIGNMENT_CENTER))
			ph.size = Vector2(Pal.em(CARD_W_EM), Pal.em(RIVAL_BACK_H_EM))
			holder.add_child(ph)
		var x := (Pal.em(CARD_W_EM) - Pal.em(RIVAL_BACK_W_EM)) / 2.0
		for j in n:
			var back := _rival_back(Pal.RED_DARK, Pal.INK, j)
			back.position.x = x
			if j == n - 1:
				var q := Ui.label("?", 2.6, Pal.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
				q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				q.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				back.add_child(q)
				_rival_tops[i] = back
			holder.add_child(back)
		if n > 0:
			var badge := HudKit.tag("x%d" % n, Pal.GOLD, Pal.HUD_INK, 0.85)
			badge.position = Vector2(x + Pal.em(RIVAL_BACK_W_EM) - Pal.em(1.2), Pal.em(RIVAL_BACK_STEP_EM) * (n - 1) + Pal.em(RIVAL_BACK_H_EM) - Pal.em(1.0))
			holder.add_child(badge)
		col.add_child(holder)
		_tip(col, "%s's station %d" % [duel.enemy_def.name, i + 1],
				"%d card%s, face down. You see the dish only when it is served." % [n, "" if n == 1 else "s"], "serve")
		(%RivalStations if i == 0 else right).add_child(col)
	%RivalStations.add_child(right)
	%RivalHand.text = "Hand %d" % k.hand.size()
	%RivalHeat.text = "Heat %d/%d" % [duel.enemy.heat, k.max_heat]
	%RivalDrawCount.text = str(k.draw_pile.size())
	%RivalKitchen.reset_size()


## Right column of a Stations panel: Station 2 over Station 3.
func _grid_right_column() -> VBoxContainer:
	var v := Ui.vbox(STATION_GAP_EM)
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _rival_back(bg: Color, border: Color, index: int) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", Ui.box(bg, border, 0.14, 0.3, 0.0))
	p.position = Vector2(0, Pal.em(RIVAL_BACK_STEP_EM) * index)
	p.size = Vector2(Pal.em(RIVAL_BACK_W_EM), Pal.em(RIVAL_BACK_H_EM))
	return p


func _refresh_stations() -> void:
	for c in %StationsRow.get_children():
		%StationsRow.remove_child(c)
		c.queue_free()
	_cols.clear()
	var right := _grid_right_column()
	for i in Duel.STATIONS:
		var frame := _station_column(i)
		(%StationsRow if i == 0 else right).add_child(frame)
		_cols.append(frame)
	%StationsRow.add_child(right)
	_highlight_stations(-1)


func _station_column(i: int) -> PanelContainer:
	var d := duel
	var st := d.stack(i)
	var tk := d.ticket(i)
	var col := Ui.vbox(0.35)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.custom_minimum_size.x = Pal.em(CARD_W_EM)
	col.add_child(Ui.label("Station %d" % (i + 1), 0.85, Pal.HUD_MUTED))
	# An empty station is just its drop slot; the Order Ticket shows once cooking starts.
	var ticket := _ticket_view(i, tk)
	ticket.visible = not st.is_empty()
	col.add_child(ticket)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := st.size()
	holder.custom_minimum_size = Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM) + Pal.em(BAND_EM) * maxi(n - 1, 0))
	if n == 0:
		var ph := HudKit.Dashed.new()
		var hint := Ui.label("+
Drop an
ingredient", 0.8, Pal.HUD_DASH, HORIZONTAL_ALIGNMENT_CENTER)
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ph.add_child(hint)
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
		serve.text = "SERVE x2" if armed else "SERVE"
		Ui.style_button(serve, Pal.GOLD if armed else Pal.RED, Pal.INK if armed else Pal.CREAM, 0.9, 0.6, 0.3)
		if armed:
			_square_button(serve, Pal.GOLD)
		else:
			HudKit.style_red_button(serve)
		serve.disabled = not d.can_serve(i).ok
		serve.pressed.connect(func() -> void: _serve(i))
		_tip(serve, "Serve", Keywords.BASE.Serve.text, "serve")
		row.add_child(serve)
		var clear := Button.new()
		clear.text = "Clear"
		Ui.style_button(clear, Pal.HUD_EMPTY, Pal.HUD_MUTED, 0.75, 0.4, 0.3)
		_square_button(clear, Pal.HUD_EMPTY)
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
	var title := "Empty"
	if recipe:
		title = recipe.name
	elif state == "improvised":
		title = "???"
	var name_l := Ui.label(title.to_upper(), 0.85, Pal.INK if state != "empty" else Pal.INK_SOFT)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	head.add_child(name_l)
	if state == "perfect" or state == "cooked":
		var stamp_bg := Pal.GOLD if state == "perfect" else Pal.PAPER
		var stamp := Ui.panel(Ui.pad(Ui.box(stamp_bg, Pal.ORANGE if state == "perfect" else Pal.INK, 0.14, 0.2, 0.0), 0.25, 0.0),
				Ui.label("PERFECT!" if state == "perfect" else "COOKED", 0.6, Pal.RED_DARK if state == "perfect" else Pal.INK))
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

	var p := HudKit.Ticket.new()
	p.paper = Pal.PAPER if state == "improvised" else Pal.CREAM
	p.glow = Pal.GOLD if state == "perfect" else Color.TRANSPARENT
	p.add_child(vb)
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
	var s := HudKit.box(bg, Pal.GOLD if top else Pal.HUD_INK, 0.2 if top else 0.16, 0.18)
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


## Rival Stations panel: right edge, mirror of Apis's.
func _place_rival_kitchen() -> void:
	_place_stations_panel(%RivalKitchen, %Root.size.x - stations_margin_px - stations_size_px.x)


## Apis's Stations panel: left edge, under the PLAYER panel.
func _place_board() -> void:
	_place_stations_panel(%Board, stations_margin_px)


func _place_stations_panel(p: Control, x: float) -> void:
	p.scale = Vector2.ONE * board_scale
	p.custom_minimum_size = stations_size_px / board_scale
	# Below the PLAYER / rival panels even when those grow (statuses), leaving room for the tab.
	var top := maxf(stations_top_px, maxf(%PlayerHud.get_rect().end.y, %Rival.get_rect().end.y) + stations_tab_room_px)
	p.position = Vector2(x, top)


## Where the next card of a station lands (global rect).
func _next_card_rect(i: int) -> Rect2:
	var holder: Control = _cols[i].get_meta("holder")
	var n := duel.stack(i).size()
	var r := holder.get_global_rect()
	var s := holder.get_global_transform().get_scale().x
	return Rect2(r.position + Vector2(0, Pal.em(BAND_EM) * n * s), Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM)) * s)


## Top card of a station (global rect), or an empty Rect2.
func _top_card_rect(i: int) -> Rect2:
	var n := duel.stack(i).size()
	if n == 0 or i >= _cols.size() or not is_instance_valid(_cols[i]):
		return Rect2()
	var holder: Control = _cols[i].get_meta("holder")
	var r := holder.get_global_rect()
	var s := holder.get_global_transform().get_scale().x
	return Rect2(r.position + Vector2(0, Pal.em(BAND_EM) * (n - 1) * s), Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM)) * s)


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
	return duel == null or _busy or %Cookbook.visible or _announcer.visible or %FlowPick.visible or %Almanac.visible


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
		v.base_scale = hand_card_scale
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
	if n == 0:
		return
	var s := hand_card_scale
	var w: float = _views[0].size.x * s
	var h: float = _views[0].size.y * s
	var step := w * (1.0 - hand_overlap)
	var area: Vector2 = %Root.size
	if n > 1:
		step = minf(step, (area.x * hand_max_width - w) / (n - 1))
	var cx := area.x / 2.0 + Pal.em(hand_offset_em)
	var top := area.y + Pal.em(hand_sink_em) * s - h
	for i in n:
		var k := i - (n - 1) / 2.0
		var v := _views[i]
		v.home_pos = v.pose_at(Vector2(cx + k * step - w / 2.0, top + Pal.em(k * k * 0.3) * s))
		v.base_y = v.pose_at(Vector2(0, top)).y
		v.home_rot = k * 3.0
		v.z_index = i


func _process(_delta: float) -> void:
	# HUD v2 panels are fixed in the scene; only the emote bubble follows the rival's head.
	# The Stations panel grows downward with its stacks (solitaire).
	_place_rival_kitchen()
	%Board.reset_size()
	_place_board()
	%Rival.reset_size()
	_emote_holder.position = anchors.rival + Vector2(Pal.em(2.6), Pal.em(0.9))
	_update_hover()
	if _almanac_queued and not _almanac_blocked():
		open_almanac()


## Hover is polled (not mouse_entered) so a lifted card does not flicker at its bottom edge.
func _update_hover() -> void:
	var target: CardView = null
	if _drag.is_empty() and _sdrag.is_empty() and not _busy and not %Cookbook.visible and not %Overlay.visible and not _announcer.visible and not %FlowPick.visible and not %Almanac.visible:
		var m: Vector2 = _mouse
		var lift := Pal.em(CardView.HOVER_LIFT_EM)
		if _hover and is_instance_valid(_hover):
			var vr := _hover.visual_rect()
			var w := vr.size.x
			var h := vr.size.y
			var r := Rect2(vr.position.x - w * 0.05, vr.position.y - lift - h * 0.15, w * 1.1, h * 1.15 + lift + h)
			if r.has_point(m):
				target = _hover
		if target == null:
			for i in range(_views.size() - 1, -1, -1):
				if _views[i].visual_rect().has_point(m):
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
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		toggle_almanac()
		return
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
	ghost.scale = Vector2.ONE * view.base_scale * 1.05
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
		tw.tween_property(ghost, "scale", Vector2.ONE * view.base_scale, 0.18)
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
			ghost.size = Vector2(Pal.em(CARD_W_EM), Pal.em(CARD_H_EM))
			ghost.scale = Vector2.ONE * board_scale
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
		var orb: Control = %HeatRow
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
## Mise en Place helped this side's opening hand (GRAND_DESIGN §4.2): shown, never hidden.
## Over Apis's stations, or over the rival's face-down stations (the swapped card stays secret).
func show_mise(side: String) -> void:
	var panel: Control = %RivalKitchen if side == "enemy" else %Board
	var at: Vector2 = panel.get_global_rect().get_center()
	_float(at + Vector2(0, -Pal.em(1.0)), "Mise en place!", Pal.GOLD, 1.3, "inspired", 0.1)


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


## Dish reveal over the served station: Apis's station, or the rival's face-down stations
## (the rival's dish is revealed only now, as it hits; GRAND_DESIGN §1.3).
func _show_dish(side: String, recipe: RecipeDef, perfect: bool, signature: bool, burnt: bool) -> void:
	var rival := side == "enemy"
	if rival:
		%DishKicker.text = ("%s SERVES" % duel.enemy_def.name.to_upper()) if recipe else "%s IMPROVISES" % duel.enemy_def.name.to_upper()
	else:
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
	if rival:
		board = %RivalKitchen.get_global_rect()
	elif si >= 0 and si < _cols.size() and is_instance_valid(_cols[si]):
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
## Apis only: the Signature Dish is the MC's move (GDD §4.5).
func _play_cutin(side: String, dish: String) -> void:
	if side != "player":
		return
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

func _build_ribbons() -> void:
	for c in %BookRibbons.get_children():
		if c is Button:
			c.queue_free()
	var seen: PackedStringArray = []
	for i in _book_recipes.size():
		var id := _book_recipes[i].book
		if id in seen:
			continue
		seen.append(id)
		var first := i
		var b := Button.new()
		b.text = id.capitalize()
		var color: Color = BOOK_COLORS.get(id, Pal.INK_SOFT)
		Ui.style_button(b, color, Pal.CREAM, 1.15, 1.0, 0.55)
		HudKit.style_ribbon(b, color)
		b.custom_minimum_size = Vector2(Pal.em(9.5), Pal.em(3.6))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func() -> void: _show_book_page(first))
		b.set_meta("book", id)
		%BookRibbons.add_child(b)


## One recipe per spread: dish + name on the left page, the cooking order top to bottom on the right.
func _show_book_page(i: int) -> void:
	if _book_recipes.is_empty():
		return
	_book_page = wrapi(i, 0, _book_recipes.size())
	var r := _book_recipes[_book_page]
	%PageDishName.text = r.name
	%PageDishBook.text = "%s · %d steps" % [r.book.capitalize(), r.requires.size()]
	%PageNum.text = "%d / %d" % [_book_page + 1, _book_recipes.size()]
	for c in %PageDishArt.get_children():
		c.queue_free()
	%PageDishArt.add_child(_dish_art(r))
	for c in %BookSteps.get_children():
		c.queue_free()
	for k in r.requires.size():
		if k > 0:
			# Containers reset child rotation, so the arrow turns inside a plain holder.
			var holder := Control.new()
			holder.custom_minimum_size = Vector2.ONE * Pal.em(1.3)
			holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var arrow := Ui.icon("arrow", Pal.HUD_INK, 1.3)
			arrow.size = holder.custom_minimum_size
			arrow.pivot_offset = arrow.size / 2.0
			arrow.rotation_degrees = 90.0
			holder.add_child(arrow)
			%BookSteps.add_child(holder)
		%BookSteps.add_child(_book_step(r.requires[k]))
	%BookEffect.text = "[center]%s[/center]" % Keywords.highlight(r.text, Pal.RED_DARK)
	for b in %BookRibbons.get_children():
		if b is Button:
			var on: bool = b.get_meta("book") == r.book
			b.position.x = 0.0
			b.modulate = Color.WHITE if on else Color(0.82, 0.78, 0.74)


## Left-page dish: the recipe's ingredients piled on a plate, first step at the bottom.
func _dish_art(r: RecipeDef) -> Control:
	var plate := HudKit.Plate.new()
	plate.custom_minimum_size = Vector2(Pal.em(15), Pal.em(15))
	var pile := Ui.vbox(-0.6)
	for k in range(r.requires.size() - 1, -1, -1):
		var tag := _req_tag(r.requires[k])
		pile.add_child(Ui.icon(tag, Pal.tag_color(tag), 4.2 if k == 0 else 3.4))
	plate.add_child(pile)
	return plate


## Right-page step: cream tile with the ingredient icon and its name.
func _book_step(req: String) -> Control:
	var tag := _req_tag(req)
	var key := req.begins_with("card:")
	var row := Ui.hbox(0.5)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(Ui.icon(tag, Pal.tag_color(tag), 2.0))
	row.add_child(Ui.label(_req_name(req), 1.05, Pal.INK))
	var s := HudKit.box(Pal.GOLD.lightened(0.55) if key else Pal.CREAM, Pal.INK_SOFT, 0.18, 0.15)
	s.shadow_color = Color("#b99a72")
	var p := Ui.panel(Ui.pad(s, 0.6, 0.15), row)
	p.custom_minimum_size = Vector2(Pal.em(13), Pal.em(2.9))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p


# ================================================================ Chef's Flow (GRAND_DESIGN §5)

## Seconds after a Serve before the pick overlay opens (the dish reveal plays first).
const FLOW_PICK_DELAY := 1.2
const FLOW_CARD_W_EM := 12.5
const FLOW_CARD_H_EM := 15.0


## "FLOW ●●○" toward the next modifier, then one chip per modifier owned (tooltip = what it does).
func _fill_flow(box: HBoxContainer, side: String) -> void:
	for c in box.get_children():
		c.queue_free()
	var k := duel.kitchen(side)
	var meter := Ui.hbox(0.2)
	meter.add_child(Ui.label("FLOW", 0.7, Pal.INK_SOFT))
	for i in k.flow_threshold():
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2.ONE * Pal.em(0.7)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override("panel", Ui.box(Pal.GOLD if i < k.flow else Pal.PAPER, Pal.INK, 0.1, 1.0, 0.0))
		meter.add_child(pip)
	_tip(meter, "Chef's Flow %d/%d" % [k.flow, k.flow_threshold()],
			"Each Perfect Order Serve fills 1. Full: pick 1 of 3 modifiers for the rest of the duel.", "check")
	box.add_child(meter)
	for id: String in k.modifiers:
		var m := GameDB.modifier(id)
		var n: int = k.modifiers[id]
		var row := Ui.hbox(0.1)
		row.add_child(Ui.icon(m.icon, Pal.GOLD if m.is_rare() else Pal.ORANGE, 1.1))
		if n > 1:
			row.add_child(Ui.label(str(n), 0.8))
		var chip := Ui.panel(Ui.pad(Ui.box(Pal.CREAM, Pal.INK, 0.13, 0.45, 0.0), 0.3, 0.1), row)
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		_tip(chip, m.name + (" x%d" % n if n > 1 else ""), m.describe(n), m.icon)
		box.add_child(chip)


func _on_flow_offer(side: String, choices: Array[ModifierDef]) -> void:
	if side != "player":
		return
	var d := duel
	await get_tree().create_timer(FLOW_PICK_DELAY).timeout
	# Still this duel's open offer (not restarted, not already picked).
	if d != duel or d.kitchen("player").offer != choices:
		return
	show_flow_pick(choices)


## The pick-1-of-3 overlay (FlowPick in duel_ui.tscn). Input is locked until a card is picked.
func show_flow_pick(choices: Array[ModifierDef]) -> void:
	_hide_tip()
	for c in %FlowChoices.get_children():
		c.queue_free()
	var k := duel.kitchen("player")
	%FlowTitle.text = "Pick a modifier"
	for m in choices:
		%FlowChoices.add_child(_flow_card(m, k.mod(m.id)))
	%FlowPick.show()
	_pop_in(%FlowBox)
	var i := 0
	for card: Control in %FlowChoices.get_children():
		card.pivot_offset = Vector2(Pal.em(FLOW_CARD_W_EM), Pal.em(FLOW_CARD_H_EM)) / 2.0
		card.scale = Vector2.ONE * 0.7
		card.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_delay(0.08 * i).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.15).set_delay(0.08 * i)
		i += 1


func _flow_card(m: ModifierDef, owned: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(Pal.em(FLOW_CARD_W_EM), Pal.em(FLOW_CARD_H_EM))
	Ui.style_button(b, Pal.CREAM, Pal.INK, 1.0, 0.8, 0.8)
	if m.is_rare():
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var sb := b.get_theme_stylebox(st).duplicate() as StyleBoxFlat
			sb.border_color = Pal.GOLD
			b.add_theme_stylebox_override(st, sb)
	b.name = "Pick_" + m.id
	var col := Ui.vbox(0.45)
	Ui.fill(col)
	col.offset_left = Pal.em(0.8)
	col.offset_right = -Pal.em(0.8)
	col.offset_top = Pal.em(0.8)
	col.offset_bottom = -Pal.em(0.8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(Ui.label("RARE" if m.is_rare() else "COMMON", 0.7, Pal.GOLD.darkened(0.25) if m.is_rare() else Pal.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER))
	var ic := Ui.icon(m.icon, Pal.GOLD if m.is_rare() else Pal.ORANGE, 3.2)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	col.add_child(Ui.label(m.name, 1.25, Pal.INK, HORIZONTAL_ALIGNMENT_CENTER))
	var text := Ui.label(m.describe(owned + 1), 0.85, Pal.INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(text)
	if owned > 0:
		col.add_child(Ui.label("Stack %d → %d" % [owned, owned + 1], 0.8, Pal.GREEN, HORIZONTAL_ALIGNMENT_CENTER))
	for n in col.find_children("*", "Control", true, false):
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	b.pressed.connect(_pick_flow.bind(m.id))
	return b


func _pick_flow(id: String) -> void:
	if duel == null or not %FlowPick.visible:
		return
	if not duel.pick_modifier(id).ok:
		return
	%FlowPick.hide()
	_refresh()


## A modifier was taken: Apis's floats up from the HUD; the rival's is announced by the
## Turn Director (TONY GOT / HOT PAN!) and floats over the rival.
func _on_modifier_gained(side: String, m: ModifierDef, stacks: int) -> void:
	var label := m.name + (" x%d" % stacks if stacks > 1 else "")
	var at: Vector2 = anchors.rival if side == "enemy" else anchors.player
	_float(at + Vector2(0, -Pal.em(1.0)), label, Pal.GOLD, 1.3, m.icon, 0.1 if side == "player" else 0.9)


# ================================================================ Almanac (GRAND_DESIGN §6)

## Almanac button / Tab: open (pauses the game) or close. On the rival's turn it waits for
## the player's turn instead of stopping the rival halfway through.
func toggle_almanac() -> void:
	if %Almanac.visible:
		%Almanac.close()
		return
	if almanac_keeper == null:
		return
	if _almanac_blocked():
		_almanac_queued = not _almanac_queued
		if _almanac_queued:
			_toast("The Almanac opens on your turn.")
		return
	open_almanac()


func open_almanac() -> void:
	_almanac_queued = false
	_hide_tip()
	if _hover:
		_hover.set_hovered(false)
		_hover = null
	%Almanac.open(almanac_keeper.almanac)


## Only on a calm moment: the Recipe Book, the result screen, or the player's own turn with
## nothing animating or being dragged.
func _almanac_blocked() -> bool:
	if %Cookbook.visible or duel == null:
		return false
	if _announcer.visible or (director and director.running):
		return true
	if duel.over():
		return false
	return duel.phase != "player" or _busy or not _drag.is_empty() or not _sdrag.is_empty()


## Red dot on the Almanac button while something new is waiting in it.
func _refresh_almanac_dot() -> void:
	%AlmanacDot.visible = almanac_keeper != null and not almanac_keeper.almanac.unseen.is_empty()
