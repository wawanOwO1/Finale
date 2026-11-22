class_name Kitchen
extends RefCounted
## One side of a duel (GRAND_DESIGN §2): the chef's stats plus everything it cooks with.
## Duel holds one Kitchen for Apis and one for the rival, and every rule (play, Serve, draw,
## Hype, Signature Dish) works on a Kitchen, so the rival plays by exactly the player's rules.
## Pure data: the rules live in Duel.

## "player" | "enemy"
var side: String
var fighter: Duel.Fighter
## Recipe Books this side has mastered.
var recipes: Array[RecipeDef] = []
## Heat and draw at the start of each of this side's turns.
var max_heat := Duel.MAX_HEAT
var hand_size := Duel.HAND_SIZE

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard: Array[CardInstance] = []
## Cards removed from this duel (played Signature Dish).
var exhausted: Array[CardInstance] = []
## Duel.STATIONS stacks of CardInstance, first placed first. Each entry is an Array[CardInstance].
var stations: Array = []
## Station of the last Serve (UI places the dish banner over it).
var last_served_station := 0

var hype := 0
## Signature Dish card was handed out (once per duel).
var signature_given := false
## Signature Dish played; the next Serve is doubled.
var signature_armed := false
var served_this_turn := false
## Top card moved to another station (once per turn, free). Clearing a station also uses it.
var moved_this_turn := false

## Shuffles this side's draw pile. Each side has its own stream, so what one side does never
## changes what the other draws (GRAND_DESIGN §4.3).
var rng: SeededRng


func _init(side_: String, fighter_: Duel.Fighter, rng_: SeededRng) -> void:
	side = side_
	fighter = fighter_
	rng = rng_
	for i in Duel.STATIONS:
		var s: Array[CardInstance] = []
		stations.append(s)


func stack(station: int) -> Array[CardInstance]:
	return stations[station]


func ingredient_count() -> int:
	var n := 0
	for s: Array[CardInstance] in stations:
		n += s.size()
	return n


func hand_index(uid: int) -> int:
	for i in hand.size():
		if hand[i].uid == uid:
			return i
	return -1


## Every card this side owns in the duel (conservation checks in tests).
func card_total() -> int:
	return draw_pile.size() + hand.size() + discard.size() + ingredient_count() + exhausted.size()
