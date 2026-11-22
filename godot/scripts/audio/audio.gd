extends Node
## Autoload "Audio": music + SFX. Listens to Duel signals (GDD §9: the logic never knows).
## Files live in res://audio/music and res://audio/sfx; names match the game state they play on.
##   Audio.play_music("battle")   Audio.sfx("bell")   Audio.bind(duel)

const MUSIC := {
	menu = preload("res://audio/music/Main_Menu.mp3"),
	deck = preload("res://audio/music/Building_Deck_Theme.mp3"),
	## Normal duels only. Boss / grand final gets its own theme later.
	battle = preload("res://audio/music/Battle_Theme.mp3"),
	victory = preload("res://audio/music/Clear_Victory.mp3"),
	game_over = preload("res://audio/music/Game_Over_Smile.mp3"),
}

const SFX := {
	boss = preload("res://audio/sfx/Boss appearance sting.mp3"),
	buff = preload("res://audio/sfx/Buff applied.mp3"),
	debuff = preload("res://audio/sfx/Debuff applied.mp3"),
	burn = preload("res://audio/sfx/Burn status applied.mp3"),
	poison = preload("res://audio/sfx/Poison status applied.mp3"),
	stun = preload("res://audio/sfx/Stun or freeze.mp3"),
	bell = preload("res://audio/sfx/Cooking bell ding.mp3"),
	pot = preload("res://audio/sfx/Ingredient added to a pot.mp3"),
	sizzle = preload("res://audio/sfx/Pan sizzle.mp3"),
	chop = preload("res://audio/sfx/Prep Board chopping.mp3"),
	round_start = preload("res://audio/sfx/Round start.mp3"),
	round_won = preload("res://audio/sfx/Round won.mp3"),
	signature = preload("res://audio/sfx/Signature Dish activation.mp3"),
	timer = preload("res://audio/sfx/Timer running out warning.mp3"),
	turn = preload("res://audio/sfx/Turn change.mp3"),
}

## Status id -> SFX key. Anything else uses buff / debuff.
const STATUS_SFX := {
	burnt = "burn",
	spicy = "poison",
}

## Tracks that repeat (set here too, so a stale import cache cannot break it).
const LOOPING: PackedStringArray = ["menu", "deck", "battle"]
const VOICES := 8
const FADE := 0.6

## Two players so tracks crossfade.
var _music: Array[AudioStreamPlayer] = []
var _active := 0
var _music_key := ""
var _voices: Array[AudioStreamPlayer] = []
var _fade_tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in LOOPING:
		MUSIC[k].loop = true
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		add_child(p)
		_music.append(p)
	for i in VOICES:
		var v := AudioStreamPlayer.new()
		v.bus = &"SFX"
		add_child(v)
		_voices.append(v)


## Crossfade to a MUSIC key ("" = fade out). Same key again keeps playing.
func play_music(key: String) -> void:
	if key == _music_key:
		return
	_music_key = key
	var old := _music[_active]
	_active = 1 - _active
	var nxt := _music[_active]
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween().set_parallel()
	if old.playing:
		_fade_tw.tween_property(old, "volume_db", -60.0, FADE)
		_fade_tw.chain().tween_callback(old.stop)
	if key != "":
		nxt.stream = MUSIC[key]
		nxt.volume_db = -60.0
		nxt.play()
		_fade_tw.tween_property(nxt, "volume_db", 0.0, FADE)


func sfx(key: String, volume_db := 0.0, pitch := 1.0) -> void:
	var v := _free_voice()
	v.stream = SFX[key]
	v.volume_db = volume_db
	v.pitch_scale = pitch
	v.play()


func _free_voice() -> AudioStreamPlayer:
	for v in _voices:
		if not v.playing:
			return v
	# All busy: steal the one that has played longest.
	var best := _voices[0]
	for v in _voices:
		if v.get_playback_position() > best.get_playback_position():
			best = v
	return best


# ---------------------------------------------------------------- duel

## Call right after the Duel is created (turn 1 has already started).
func bind(d: Duel) -> void:
	d.turn_started.connect(func(_turn: int) -> void: sfx("turn"))
	d.card_played.connect(_on_card_played)
	d.dish_revealed.connect(_on_dish)
	d.status_applied.connect(_on_status)
	d.duel_ended.connect(_on_duel_ended)
	if d.enemy_def.boss:
		sfx("boss")
		play_music("")  # Boss theme not made yet: no Battle_Theme for the grand final.
	else:
		sfx("round_start")
		play_music("battle")


func _on_card_played(card: CardInstance) -> void:
	if card.def.special == "signature":
		sfx("signature")
	elif card.def.is_ingredient():
		sfx("chop")
	else:
		sfx("sizzle")


func _on_status(_target: String, status: String, _amount: int) -> void:
	sfx(STATUS_SFX.get(status, "debuff" if StatusDefs.is_debuff(status) else "buff"))


func _on_duel_ended(winner: String) -> void:
	if winner == "player":
		sfx("round_won")
		play_music("victory")
	else:
		play_music("game_over")


## Plate goes into the pot, then the bell rings with the dish reveal.
func _on_dish(_recipe: RecipeDef, _perfect: bool, _signature: bool, _burnt: bool) -> void:
	sfx("pot")
	get_tree().create_timer(0.18).timeout.connect(sfx.bind("bell"))
