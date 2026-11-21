class_name DuelUI
extends CanvasLayer
## Duel HUD. Layout lives in duel_ui.tscn (edit it in the 2D editor); this script only fills
## it from the Duel state on every `changed` signal and forwards clicks.
## Shortcuts: E = End Turn, S = Serve.

signal restart_requested

const CARD_VIEW := preload("res://scenes/ui/card_view.tscn")

var duel: Duel


func _ready() -> void:
	%ServeButton.pressed.connect(_on_serve)
	%EndTurnButton.pressed.connect(_on_end_turn)
	%RestartButton.pressed.connect(func() -> void: restart_requested.emit())
	%Cookbook.hide()
	%EndOverlay.hide()
	%Toast.text = ""


## Pre-duel Recipe Book (the book is closed during the duel: memorize the orders).
## Await it: `await ui.show_cookbook(recipes)`.
func show_cookbook(recipes: Array[RecipeDef]) -> void:
	%EndOverlay.hide()
	for child in %RecipeList.get_children():
		child.queue_free()
	for r in recipes:
		var line := Label.new()
		line.text = "%s   [%s]   →  %s" % [r.name, "  →  ".join(_pretty_reqs(r)), r.text]
		%RecipeList.add_child(line)
	%Cookbook.show()
	await %StartButton.pressed
	%Cookbook.hide()


func bind(d: Duel) -> void:
	duel = d
	duel.changed.connect(_refresh)
	duel.duel_ended.connect(_on_duel_ended)
	duel.dish_revealed.connect(_on_dish_revealed)
	duel.signature_ready.connect(func() -> void: _toast("The crowd goes wild! Signature Dish unlocked!"))
	%RivalName.text = "%s — %s" % [duel.enemy_def.name, duel.enemy_def.title]
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if duel == null or key == null or not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_E:
			_on_end_turn()
		KEY_S:
			_on_serve()


# ---------------------------------------------------------------- refresh

func _refresh() -> void:
	var p := duel.player
	var e := duel.enemy

	%HypeBar.value = duel.hype
	%HypeValue.text = "%d / %d" % [duel.hype, Duel.MAX_HYPE]

	%RivalConf.max_value = e.max_confidence
	%RivalConf.value = e.confidence
	%RivalConfLabel.text = "Confidence %d / %d   Composure %d" % [e.confidence, e.max_confidence, e.composure]
	%RivalStatuses.text = _status_text(e)
	%RivalStatuses.tooltip_text = _status_tooltip(e)
	%Intent.text = "Next: " + _intent_text(duel.intent())

	%PlayerConf.max_value = p.max_confidence
	%PlayerConf.value = p.confidence
	%PlayerConfLabel.text = "Confidence %d / %d" % [p.confidence, p.max_confidence]
	%PlayerStats.text = "Composure %d    Heat %d / %d" % [p.composure, p.heat, Duel.MAX_HEAT]
	%PlayerStatuses.text = _status_text(p)
	%PlayerStatuses.tooltip_text = _status_tooltip(p)

	# Prep Board: ingredients in placement order. The book is closed: no recipe hints.
	for child in %Slots.get_children():
		child.queue_free()
	for c in duel.plate:
		var slot := Label.new()
		slot.text = "%s\n%s" % [c.def.name, c.def.first_tag()]
		slot.custom_minimum_size = Vector2(96, 56)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		%Slots.add_child(slot)
	%BoardCount.text = "Prep Board  %d / %d" % [duel.plate.size(), Duel.PLATE_SIZE]
	%ServeButton.disabled = not duel.can_serve().ok
	%ServeButton.text = "SERVE (1 Heat)%s" % ("  ×2" if duel.signature_armed else "")

	for child in %Hand.get_children():
		child.queue_free()
	for c in duel.hand:
		var view: CardView = CARD_VIEW.instantiate()
		%Hand.add_child(view)
		view.setup(c, duel.can_play(c.uid).ok)
		view.pressed.connect(_on_card_pressed.bind(c.uid))

	%Piles.text = "Draw %d   Discard %d" % [duel.draw_pile.size(), duel.discard.size()]
	%EndTurnButton.disabled = duel.phase != "player"
	%Log.text = "\n".join(duel.log_lines.slice(-12))


func _status_text(f: Duel.Fighter) -> String:
	var parts: PackedStringArray = []
	for id: String in f.statuses:
		parts.append("%s %d" % [StatusDefs.display_name(id), f.statuses[id]])
	return ", ".join(parts)


func _status_tooltip(f: Duel.Fighter) -> String:
	var parts: PackedStringArray = []
	for id: String in f.statuses:
		parts.append("%s: %s" % [StatusDefs.display_name(id), StatusDefs.ALL[id].text])
	return "\n".join(parts)


func _intent_text(it: IntentDef) -> String:
	var parts: PackedStringArray = [it.label]
	if it.has_attack():
		parts.append("Attack %d" % duel.pressure_from("enemy", it.attack))
	if it.block > 0:
		parts.append("Block %d" % it.block)
	if it.has_status():
		var who := "you" if it.status_target == IntentDef.StatusTarget.PLAYER else "self"
		parts.append("%s %d (%s)" % [StatusDefs.display_name(it.status), it.status_amount, who])
	return " · ".join(parts)


func _pretty_reqs(r: RecipeDef) -> PackedStringArray:
	var out: PackedStringArray = []
	for req in r.requires:
		out.append(GameDB.card(req.substr(5)).name if req.begins_with("card:") else req)
	return out


# ---------------------------------------------------------------- actions

func _on_card_pressed(uid: int) -> void:
	_report(duel.play(uid))


func _on_serve() -> void:
	_report(duel.serve())


func _on_end_turn() -> void:
	_report(duel.end_turn())


func _report(result: Dictionary) -> void:
	if not result.ok:
		_toast(result.reason)


func _toast(text: String) -> void:
	%Toast.text = text
	var tw := create_tween()
	%Toast.modulate.a = 1.0
	tw.tween_interval(1.6)
	tw.tween_property(%Toast, "modulate:a", 0.0, 0.4)


func _on_dish_revealed(recipe: RecipeDef, perfect: bool, signature: bool, burnt: bool) -> void:
	var label := recipe.name if recipe else "Improvised Dish"
	if perfect:
		label += " — Perfect Order!"
	if signature:
		label += " — SIGNATURE ×2"
	if burnt:
		label += " (Burnt)"
	_toast(label)


func _on_duel_ended(winner: String) -> void:
	%ResultLabel.text = "%s gives up! You win." % duel.enemy_def.name if winner == "player" else "Apis loses heart..."
	%EndOverlay.show()
