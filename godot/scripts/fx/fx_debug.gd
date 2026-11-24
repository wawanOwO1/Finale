class_name FxDebug
extends Label
## F3 overlay (FX_MASTERPLAN.md §7.2): FPS, frame time, draw calls, live particles and FX state,
## for checking the budget (§2.1) in the web build. The %FxDebug node in duel_ui.tscn.
## F3 shows / hides it; Shift+F3 toggles FX Quality Low (FxDirector).

## Set by main.gd.
var fx: FxDirector
var _acc := 0.0


func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F3 and not k.shift_pressed:
		visible = not visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta / maxf(0.01, Engine.time_scale)
	if _acc < 0.25:
		return
	_acc = 0.0
	text = report()


## The overlay text (also handy in tests).
func report() -> String:
	var lines := PackedStringArray()
	lines.append("FPS %d   frame %.1f ms" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
	lines.append("draw calls %d   objects %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	if fx:
		lines.append("particles %d / 150" % (fx.hud.live_particles() if fx.hud else 0))
		lines.append("FX quality %s%s   (Shift+F3)" % ["LOW" if fx.quality_low else "HIGH", " auto" if fx.auto_switched else ""])
		lines.append("time scale %.2f   overlay %s   lines %s" % [Engine.time_scale, "on" if fx.screen and fx.screen.visible else "off",
				"on" if fx.lines_value() > 0.0 else "off"])
		var cut := "signature" if fx.cutscene and fx.cutscene.playing else ("finish" if fx.finish and fx.finish.playing else "-")
		lines.append("cutscene %s   hold %s (%d)" % [cut, fx.hold, fx.pending()])
	return "\n".join(lines)
