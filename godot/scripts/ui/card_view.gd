class_name CardView
extends Control
## One card in hand. Layout lives in card_view.tscn; this fills it from a CardInstance and
## owns the card's own motion (fan pose, hover lift, deal-in, shake). DuelUI does the drag.

## Card v2 (canvas board "Kartu v2"): cream rim (gold for Signature), dark body, teal cost block,
## name banner, art window tinted per type, Quality bar on ingredients.
const TECH_ART := Color("#2f6f7a")
const SIG_ART := Color("#4a2a3a")
const HOVER_LIFT_EM := 4.4
const HOVER_SCALE := 1.16

var card: CardInstance
var playable := true
## Fan pose set by DuelUI.layout_hand().
var home_pos := Vector2.ZERO
var home_rot := 0.0
## Fan y without the arc lift; hover lifts from here.
var base_y := 0.0
var hovered := false

var _tween: Tween
var _glow: Tween


func setup(card_: CardInstance, playable_: bool, tips_left: bool) -> void:
	card = card_
	playable = playable_
	var d := card.def
	var sig := d.special == "signature"
	var tag := "technique" if not d.is_ingredient() else d.first_tag()
	%CostLabel.text = str(d.cost)
	%Name.text = d.name
	%Type.text = "Signature" if sig else ("Ingredient · %s" % tag if d.is_ingredient() else "Technique")
	%Text.text = "[center]%s[/center]" % Keywords.highlight(d.text)

	var body: StyleBoxFlat = %Body.get_theme_stylebox("panel").duplicate()
	body.bg_color = Pal.CARD_RIM_RARE if sig else Pal.CARD_RIM
	%Body.add_theme_stylebox_override("panel", body)
	var banner: StyleBoxFlat = %Banner.get_theme_stylebox("panel").duplicate()
	banner.bg_color = Pal.GOLD if sig else Pal.CARD_BANNER
	%Banner.add_theme_stylebox_override("panel", banner)

	var art: StyleBoxFlat = %Art.get_theme_stylebox("panel").duplicate()
	art.bg_color = SIG_ART if sig else (Pal.tag_color(tag).darkened(0.55) if d.is_ingredient() else TECH_ART)
	%Art.add_theme_stylebox_override("panel", art)
	%ArtIcon.texture = Ui.icon_tex("crown" if sig else tag)
	%ArtIcon.self_modulate = Pal.GOLD if sig else (Pal.tag_color(tag).lightened(0.15) if d.is_ingredient() else Pal.CREAM)
	%QualityBar.visible = d.is_ingredient()
	%QualityBar.value = d.quality

	# Keyword tips beside the card (left side for cards right of center).
	for child in %Tips.get_children():
		child.queue_free()
	%Tips.add_child(_tip(Keywords.card_role(d)))
	for k in Keywords.for_card(d):
		%Tips.add_child(_tip(k))
	if tips_left:
		%Tips.position.x = -Pal.em(13.0 + 0.6)

	modulate = Color.WHITE if playable else Color(0.86, 0.83, 0.8)
	if sig:
		_start_glow(body)


func _tip(k: Dictionary) -> Control:
	return Ui.tip_box(k.name, k.text, k.icon)


## Snap or glide to the fan pose.
func go_home(animated := true) -> void:
	_kill()
	var target_pos := home_pos
	var target_rot := home_rot
	var target_scale := Vector2.ONE
	if hovered:
		target_pos.y = base_y - Pal.em(HOVER_LIFT_EM)
		target_rot = 0.0
		target_scale = Vector2.ONE * HOVER_SCALE
	if not animated:
		position = target_pos
		rotation_degrees = target_rot
		scale = target_scale
		return
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", target_pos, 0.16)
	_tween.tween_property(self, "rotation_degrees", target_rot, 0.16)
	_tween.tween_property(self, "scale", target_scale, 0.16)


## Hovering lifts the card out of the fan and shows its keyword tips.
func set_hovered(on: bool) -> void:
	if hovered == on:
		return
	hovered = on
	%Tips.visible = on
	z_index = 60 if on else get_index()
	go_home()


## New card flies in from the draw pile side, staggered by `delay`.
func deal_in(delay: float) -> void:
	_kill()
	position = home_pos + Vector2(Pal.em(-18), Pal.em(4))
	rotation_degrees = home_rot - 25.0
	modulate.a = 0.0
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position", home_pos, 0.32).set_delay(delay)
	_tween.tween_property(self, "rotation_degrees", home_rot, 0.32).set_delay(delay)
	_tween.tween_property(self, "modulate:a", 1.0, 0.2).set_delay(delay)


## Rejected (can't play): quick sideways shake.
func shake() -> void:
	_kill()
	var x := position.x
	_tween = create_tween()
	for dx in [-0.4, 0.4, -0.2, 0.0]:
		_tween.tween_property(self, "position:x", x + Pal.em(dx), 0.065)


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _start_glow(body: StyleBoxFlat) -> void:
	body.shadow_size = 8
	_glow = create_tween().set_loops()
	_glow.tween_property(body, "shadow_color", Color("#ff7a1a"), 0.8)
	_glow.tween_property(body, "shadow_color", Color("#ffb43a"), 0.8)
