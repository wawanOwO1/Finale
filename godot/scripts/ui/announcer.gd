class_name Announcer
extends Control
## Match flow text (ART_DIRECTION §7, ref 6): 3 · 2 · 1 → ROUND N / FIGHT! at the start,
## FINISHED → YOU WINS! or LOSER at the end, and the turn banners in between.
## Full-screen; blocks clicks while it plays.
##   await announcer.intro(2)      await announcer.result(true)      await announcer.turn_banner(…)

const WIN_TEXT := "YOU WINS!"
const LOSE_TEXT := "LOSER"

var _strip: ColorRect
var _kicker: Label
var _big: Label
var _letters: HBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	Ui.fill(self)
	_strip = ColorRect.new()
	_strip.color = Color(Pal.INK, 0.82)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_strip)
	_kicker = Ui.outlined("", 1.6, Pal.GOLD, 0.12)
	add_child(_kicker)
	_big = Ui.outlined("", 6.5, Pal.CREAM, 0.3)
	add_child(_big)
	_letters = Ui.hbox(0.1)
	add_child(_letters)
	hide()


func intro(round_n: int) -> void:
	_open()
	for n in [3, 2, 1]:
		_kicker.text = "ROUND %d" % round_n
		await _slam(str(n), Pal.CREAM, 0.62)
		_sfx("turn", -6.0, 1.0 + (3 - n) * 0.12)
	_kicker.text = "ROUND %d" % round_n
	_sfx("bell")
	await _slam("FIGHT!", Pal.CREAM, 0.95, Pal.RED, true)
	await _close()


func result(won: bool) -> void:
	_open()
	_kicker.text = ""
	await _slam("FINISHED", Pal.CREAM, 1.0)
	_kicker.text = "FINISHED"
	if won:
		await _slam(WIN_TEXT, Pal.GOLD, 1.6, Pal.RED_DARK, true)
	else:
		await _fall_letters(LOSE_TEXT)
	await _close()


## Turn hand-over banner (GRAND_DESIGN §1.2 P1 / E1): "YOUR TURN" or "TONY'S TURN", ~1.1 s.
func turn_banner(text: String, color: Color, kicker := "", sfx := true) -> void:
	_open()
	_kicker.text = kicker
	if sfx:
		_sfx("turn")
	await _slam(text, color, 0.55, Pal.INK, true)
	await _close()


# ---------------------------------------------------------------- internals

func _open() -> void:
	show()
	modulate.a = 1.0
	var area := get_parent_area_size()
	_strip.position = Vector2(0, area.y * 0.5 - Pal.em(6))
	_strip.size = Vector2(area.x, Pal.em(12))
	_strip.scale = Vector2(1, 0)
	_strip.pivot_offset = Vector2(0, Pal.em(6))
	create_tween().tween_property(_strip, "scale:y", 1.0, 0.15)
	_big.text = ""
	_letters.hide()


func _close() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	await tw.finished
	hide()


## Big word pops in with squash & stretch, holds, then clears.
func _slam(text: String, color: Color, hold: float, shadow := Pal.INK, skew := false) -> void:
	_letters.hide()
	_big.show()
	_big.text = text
	_big.add_theme_color_override("font_color", color)
	_big.add_theme_color_override("font_shadow_color", shadow)
	_big.add_theme_constant_override("shadow_offset_x", roundi(Pal.em(0.35)))
	_big.add_theme_constant_override("shadow_offset_y", roundi(Pal.em(0.35)))
	_layout()
	_big.pivot_offset = _big.size / 2.0
	_big.rotation_degrees = -4.0 if skew else 0.0
	_big.scale = Vector2(1.6, 0.5)
	var tw := create_tween()
	tw.tween_property(_big, "scale", Vector2(0.92, 1.12), 0.12).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_big, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(hold)
	await tw.finished


## LOSER: letters drop in one by one and land crooked.
func _fall_letters(text: String) -> void:
	_big.hide()
	for c in _letters.get_children():
		c.queue_free()
	_letters.show()
	var labels: Array[Label] = []
	for ch in text:
		var l := Ui.outlined(ch, 6.5, Color("#c9b8a3"), 0.3)
		l.add_theme_color_override("font_shadow_color", Pal.RED_DARK)
		l.add_theme_constant_override("shadow_offset_x", roundi(Pal.em(0.3)))
		l.add_theme_constant_override("shadow_offset_y", roundi(Pal.em(0.3)))
		l.modulate.a = 0.0
		_letters.add_child(l)
		labels.append(l)
	_letters.reset_size()
	var area := get_parent_area_size()
	_letters.position = Vector2((area.x - _letters.size.x) / 2.0, area.y * 0.5 - _letters.size.y * 0.42)
	_kicker.reset_size()
	_kicker.position = Vector2((area.x - _kicker.size.x) / 2.0, area.y * 0.5 - Pal.em(5.6))
	await get_tree().process_frame
	var tw := create_tween()
	for i in labels.size():
		var l := labels[i]
		l.pivot_offset = l.size / 2.0
		var land: float = l.position.y + [0.0, 0.25, 0.0, 0.45, 0.1][i % 5] * Pal.em(1)
		l.position.y -= Pal.em(6)
		tw.tween_property(l, "modulate:a", 1.0, 0.01)
		tw.tween_property(l, "position:y", land, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "rotation_degrees", [0.0, -6.0, 3.0, 8.0, -3.0][i % 5], 0.22)
	tw.tween_interval(1.4)
	await tw.finished


func _layout() -> void:
	var area := get_parent_area_size()
	_big.reset_size()
	_kicker.reset_size()
	_big.position = Vector2((area.x - _big.size.x) / 2.0, area.y * 0.5 - _big.size.y * 0.42)
	_kicker.position = Vector2((area.x - _kicker.size.x) / 2.0, area.y * 0.5 - Pal.em(5.6))


func _sfx(key: String, volume_db := 0.0, pitch := 1.0) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.sfx(key, volume_db, pitch)
