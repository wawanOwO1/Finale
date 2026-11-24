class_name FxHud
extends Control
## HUD-side FX pool (FX_MASTERPLAN.md §4.4, §5.4, §5.6): the %FxHud node in duel_ui.tscn.
## Children are made in the scene, never at hit time:
##   CPUParticles2D named <Kind>1, <Kind>2 (Crumbs1, Steam2, …): one-shot bursts, used round robin.
##   Label nodes named Word1, Word2: manga sound words.
## CPUParticles2D, not GPU: a few dozen particles cost nothing on the CPU, and there is no
## particle shader for WebGL to compile on the first Serve. No texture: each particle is a square
## pixel, scaled up (pixel-art look, no atlas to download).

## Seconds a word stays before it floats off.
@export var word_hold := 0.45
## Word size by tier (T1, T2, T3), in em.
@export var word_em := PackedFloat32Array([3.2, 4.4, 5.6])
## Settings: 0.5 halves every burst (FX Quality Low).
@export_range(0.0, 1.0, 0.05) var amount_scale := 1.0

var _next := {}
var _word_i := 0
var _word_tw: Array[Tween] = [null, null]
## Kind → frame of its last burst: one burst per kind per frame, however many signals fire.
var _burst_frame := {}
## One word per frame: a Serve can fire several cues at once, only the strongest gets its word.
var _word_frame := -1
var _word_tier := 0
var _word_slot := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in get_children():
		if c is CPUParticles2D:
			c.emitting = false
			c.one_shot = true
			c.set_meta("base_amount", c.amount)
		elif c is Label:
			c.hide()


## One-shot burst of `kind` at a HUD position. color: tint (crumbs take the ingredient's color).
func burst(kind: String, at: Vector2, color := Color.WHITE, size := 1.0) -> CPUParticles2D:
	if kind == "" or kind == "none":
		return null
	var f := Engine.get_process_frames()
	if _burst_frame.get(kind, -1) == f:
		return null
	_burst_frame[kind] = f
	var p := _pick(kind)
	if p == null:
		return null
	p.position = at
	p.color = color
	p.amount = maxi(1, roundi(p.get_meta("base_amount") * amount_scale * size))
	p.restart()
	return p


## Slam a manga word (tier 1..3 → size). Two words can overlap; a third reuses the oldest.
func word(text: String, at: Vector2, color: Color, tier: int) -> Label:
	if text == "":
		return null
	var f := Engine.get_process_frames()
	var slot := _word_i
	if f == _word_frame:
		if tier <= _word_tier:
			return null
		slot = _word_slot  # a stronger cue in the same frame takes over its word
	else:
		_word_i = (_word_i + 1) % 2
	_word_frame = f
	_word_tier = tier
	_word_slot = slot
	var l := get_node_or_null("Word%d" % (slot + 1)) as Label
	if l == null:
		return null
	if _word_tw[slot] and _word_tw[slot].is_valid():
		_word_tw[slot].kill()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", roundi(Pal.em(word_em[clampi(tier - 1, 0, 2)])))
	l.show()
	l.reset_size()
	l.pivot_offset = l.size / 2.0
	# Keep the whole word on screen (bars sit at the top edge).
	var m := Pal.em(0.5)
	var p := (at - l.size / 2.0).clamp(Vector2(m, m), size - l.size - Vector2(m, m))
	l.position = p
	l.rotation = deg_to_rad(randf_range(-10.0, 10.0))
	l.scale = Vector2.ONE * 1.9
	l.modulate.a = 1.0
	var tw := create_tween()
	_word_tw[slot] = tw
	tw.tween_property(l, "scale", Vector2.ONE * 0.92, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.08)
	tw.tween_interval(word_hold)
	tw.tween_property(l, "position", p - Vector2(0, Pal.em(1.5)), 0.3).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_callback(l.hide)
	return l


## Particles alive right now (budget check, F3 overlay later).
func live_particles() -> int:
	var n := 0
	for c in get_children():
		if c is CPUParticles2D and c.emitting:
			n += c.amount
	return n


## Draw every burst once with nothing visible, so the first real one does not hitch.
func prewarm() -> void:
	for c in get_children():
		if c is CPUParticles2D:
			c.position = Vector2(-500, -500)
			c.restart()


func _pick(kind: String) -> CPUParticles2D:
	var base := kind.capitalize()
	var i: int = _next.get(kind, 0)
	var p := get_node_or_null("%s%d" % [base, i + 1]) as CPUParticles2D
	if p == null:
		p = get_node_or_null("%s1" % base) as CPUParticles2D
		i = 0
	_next[kind] = (i + 1) % 2
	return p
