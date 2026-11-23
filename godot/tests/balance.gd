extends SceneTree
## Balancing harness (GRAND_DESIGN §8, phase G): AI vs AI, hundreds of duels per rival.
## Prints win rate, duel length, Confidence left, rival actions per turn, Chef's Flow and
## Perfect rate. Changes nothing; tune the numbers in the .tres files / Main's Inspector.
## Run (headless):
##   godot --headless --path godot --script res://tests/balance.gd            current data
##   godot --headless --path godot --script res://tests/balance.gd -- sweep   try other values
##
## Bots: see tests/balance_runner.gd.

const N := 300
const SWEEP_N := 150

const Bots := preload("res://tests/balance_runner.gd")


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("sweep"):
		_sweep()
	else:
		_report()
	quit()


func _report() -> void:
	print("Balance with the current data (%d duels each)\n" % N)
	for id in ["tony", "rosa"]:
		for bot in ["simple", "smart"]:
			print(_line(id, bot, Bots.run(GameDB.enemy(id), bot, N, {})))


## Grid of player max Confidence × rival Confidence × player Flow thresholds, the levers for
## duel length, win rate and how often Chef's Flow fires. Override any axis on the command
## line: -- sweep hp=60,80 tony=40,50 rosa=50,60 flow=234,123 n=150
func _sweep() -> void:
	var opt := {hp = "80,100,120", tony = "40,45,50", rosa = "45,50,55", flow = "123,234", n = str(SWEEP_N)}
	for a in OS.get_cmdline_user_args():
		if "=" in a:
			opt[a.get_slice("=", 0)] = a.get_slice("=", 1)
	var n := int(opt.n)
	for id in ["tony", "rosa"]:
		var base := GameDB.enemy(id)
		for hp in opt.hp.split(","):
			for conf in opt[id].split(","):
				var e: EnemyDef = base.duplicate()
				e.confidence = int(conf)
				for f in opt.flow.split(","):
					var flow := PackedInt32Array()
					for ch in f:
						flow.append(int(ch))
					for bot in ["simple", "smart"]:
						var s := Bots.run(e, bot, n, {player_flow = flow, max_confidence = int(hp)})
						print(_line("%s hp %s conf %s flow %s" % [id, hp, conf, f], bot, s, int(hp)))
		print("")


func _line(label: String, bot: String, s: Dictionary, hp := Duel.PLAYER_CONFIDENCE) -> String:
	return "%-30s %-6s win %3d%%  turns %.1f (5-8: %2d%%)  conf left %2.0f/%d  rival acts/turn %.1f (max %d)  flow Apis %.2f rival %.2f  perfect %2d%%" % [
			label, bot, s.win_pct, s.turns, s.in_range_pct, s.conf_left, hp, s.acts_per_turn, s.max_acts,
			s.flow_player, s.flow_enemy, s.perfect_pct]

