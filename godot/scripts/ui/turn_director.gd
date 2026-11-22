class_name TurnDirector
extends Node
## Paces the turn loop (GRAND_DESIGN §1): YOUR TURN banner → player turn → RIVAL'S TURN banner
## → rival acts one step at a time → YOUR TURN … until the duel ends.
## Duel stays pure logic; this node only decides *when* to call its turn API and waits for the
## animations in between. Hold the left mouse button or Space to fast-forward the rival.
##
## Lives in main.tscn (node "TurnDirector"): tune the timings in its Inspector.
## The "hold to speed up" hint is the SpeedHint label in duel_ui.tscn.

## Emitted right after a rival step is applied (the stage hops the rival chef).
signal rival_acted(action: Dictionary)

@export_group("Rival turn (seconds)")
## E3: "…" bubble before each rival step.
@export var think := 0.35
@export var hold_attack := 0.7
@export var hold_block := 0.55
@export var hold_status := 0.6
## E2: pause after Composure fades / Spicy ticks, before the first step.
@export var start_pause := 0.35
## E4: pause after the last step, before the YOUR TURN banner.
@export var end_pause := 0.4
@export_group("Fast-forward")
## Time scale while the player holds click or Space on the rival turn.
@export var fast_scale := 3.0

## Set by main.gd.
var ui: DuelUI
## True from End Turn until the player's next turn starts (or the duel ends).
var running := false


func _process(_delta: float) -> void:
	var fast := running and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE))
	Engine.time_scale = fast_scale if fast else 1.0
	if ui:
		ui.speed_hint().modulate.a = 1.0 if fast else 0.75


func is_fast() -> bool:
	return Engine.time_scale > 1.0


## Opening banner after the 3 · 2 · 1 FIGHT! intro (hand is already dealt).
func first_turn() -> void:
	await ui.announcer().turn_banner("YOUR TURN", Pal.GOLD, "TURN %d" % ui.duel.turn, false)


## End Turn was accepted (duel.phase == "enemy"): play the whole rival turn, then hand back.
func rival_turn() -> void:
	var d := ui.duel
	if d == null or d.phase != "enemy" or running:
		return
	running = true
	ui.set_busy(true)
	await ui.announcer().turn_banner("%s'S TURN" % d.enemy_def.name.to_upper(), Pal.RED)
	ui.speed_hint().visible = _live(d)
	# E2: Composure fades, Spicy ticks (its number floats up before the first action).
	d.begin_enemy_turn()
	await _wait(start_pause)
	while _live(d):
		if not is_fast() and d.enemy_actions_left() > 0:
			await ui.rival_think(think)
		if not _live(d):
			break
		var a := d.enemy_step()
		if a.kind == "end" or a.kind == "none":
			break
		rival_acted.emit(a)
		ui.rival_act(a)
		await _wait(_hold(a.kind))
	if _live(d):
		await _wait(end_pause)
		ui.speed_hint().hide()
		running = false
		await ui.announcer().turn_banner("YOUR TURN", Pal.GOLD, "TURN %d" % (d.turn + 1), false)
		if _live(d):
			d.start_player_turn()
	ui.speed_hint().hide()
	running = false
	# A finished duel keeps the input locked; DuelUI's result sequence takes over.
	if d == ui.duel and not d.over():
		ui.set_busy(false)


## How long a rival step stays on screen before the next one (GRAND_DESIGN §1.3).
func _hold(kind: String) -> float:
	match kind:
		"attack":
			return hold_attack
		"block":
			return hold_block
		"status":
			return hold_status
	return 0.5


## Still this duel's rival turn (not restarted, not won/lost).
func _live(d: Duel) -> bool:
	return d == ui.duel and d.phase == "enemy"


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
