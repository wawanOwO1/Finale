class_name RunState
extends RefCounted
## Everything a run carries from duel to duel (GDD §6): the deck, Confidence, Tips, the mastered
## Recipe Books and the Kitchen Tools. Pure data + rules, no nodes: Main owns one, the Course
## Path, Reward, Shop and Practice Kitchen read and change it, and every duel is built from it.
##
## Confidence is the run's health: it carries over between duels and only comes back through
## the Practice Kitchen (heal). Modifiers and Chef's Flow are per duel and are NOT stored here
## (GRAND_DESIGN §5, MODIFIERS.md); Kitchen Tools are the permanent part.

const START_DECK := "starter"
const START_BOOKS: PackedStringArray = ["basics"]
const REPUTATION_THRESHOLD := 4

var deck: Array[CardDef] = []
var confidence := Duel.PLAYER_CONFIDENCE
var max_confidence := Duel.PLAYER_CONFIDENCE
var tips := 0
## Mastered Recipe Book ids, in the order they were gained (book order = recipe order).
var books: PackedStringArray = []
## Kitchen Tool ids (ToolDef arrives with the Kitchen Tools task).
var tools: PackedStringArray = []
var duels_won := 0
## Reputation (GDD §4.11): the player's Cooked/Perfect recipe Serves per cuisine over the run.
var cuisine_serves := {}
## Serves a cuisine needs (and must lead the rest by at least 1) to become your Reputation.
var reputation_threshold := REPUTATION_THRESHOLD
## True once a duel was lost: the run is over and this state is not used for another duel.
var over := false

## The last duel settled by finish_duel, so settling it twice cannot count it twice.
var _settled: Duel = null


## A fresh run: the starter deck (or `deck_id`), the Basics Cookbook (or `book_ids`), full
## Confidence and no Tips or Tools.
static func start(max_confidence_ := Duel.PLAYER_CONFIDENCE, deck_id := START_DECK,
		book_ids: PackedStringArray = START_BOOKS) -> RunState:
	var r := RunState.new()
	r.deck = GameDB.deck(deck_id)
	r.max_confidence = max_confidence_
	r.confidence = max_confidence_
	for id in book_ids:
		r.add_book(id)
	return r


# ================================================================ duels

## The mastered books' recipes, in book order: the Recipe Book of the next duel.
func recipes() -> Array[RecipeDef]:
	return GameDB.book_recipes(books)


## A copy, so a duel can never change the run's deck.
func duel_deck() -> Array[CardDef]:
	return deck.duplicate()


## Options for Duel.new: the run's Confidence goes in, `extra` (seed, hype, player_flow, …)
## is merged on top.
func duel_opts(extra := {}) -> Dictionary:
	var opts := {confidence = confidence, max_confidence = max_confidence, reputation = reputation()}
	opts.merge(extra, true)
	return opts


## Build the next duel from the run.
func new_duel(enemy: EnemyDef, extra := {}) -> Duel:
	return Duel.new(duel_deck(), enemy, recipes(), duel_opts(extra))


## Settle a finished duel: a win carries the Confidence you have left (never below 1), a loss
## ends the run. A duel still in progress changes nothing.
func finish_duel(d: Duel) -> void:
	if d == _settled:
		return
	if d.over():
		for c: String in d.cuisine_serves:
			cuisine_serves[c] = cuisine_serves.get(c, 0) + int(d.cuisine_serves[c])
	match d.phase:
		"won":
			confidence = clampi(d.player.confidence, 1, max_confidence)
			duels_won += 1
		"lost":
			over = true
		_:
			return
	_settled = d


## Your Reputation (GDD §4.11): the cuisine you served most this run, once it has at least
## `reputation_threshold` Serves and is strictly ahead of every other. "" = none yet.
func reputation() -> String:
	var best := ""
	var best_n := 0
	var second_n := 0
	for c: String in cuisine_serves:
		if c == RecipeDef.HOME:
			continue
		var n: int = cuisine_serves[c]
		if n > best_n:
			second_n = best_n
			best_n = n
			best = c
		elif n > second_n:
			second_n = n
	return best if best_n >= reputation_threshold and best_n > second_n else ""


# ================================================================ Confidence

## Heal (Practice Kitchen rest, Tools, events). Returns how much was actually restored.
func heal(amount: int) -> int:
	var before := confidence
	confidence = clampi(confidence + amount, 1, max_confidence)
	return confidence - before


## Raise (or, negative, lower) the cap; Confidence follows by the same amount, never over the cap.
func change_max_confidence(amount: int) -> void:
	max_confidence = maxi(1, max_confidence + amount)
	confidence = clampi(confidence + maxi(amount, 0), 1, max_confidence)


# ================================================================ Tips

func add_tips(amount: int) -> void:
	tips += maxi(amount, 0)


func can_afford(cost: int) -> bool:
	return tips >= cost


## False (and nothing spent) when you cannot pay.
func spend_tips(cost: int) -> bool:
	if cost < 0 or tips < cost:
		return false
	tips -= cost
	return true


# ================================================================ deck, books, tools

func add_card(card: CardDef) -> void:
	deck.append(card)


## Removes one copy of this card (Shop card removal). False when the deck has none.
func remove_card(card: CardDef) -> bool:
	var i := deck.find(card)
	if i < 0:
		return false
	deck.remove_at(i)
	return true


func count_card(card: CardDef) -> int:
	return deck.count(card)


func has_book(id: String) -> bool:
	return books.has(id)


## Mastering a book gives its recipes to every later duel. False when owned or unknown.
func add_book(id: String) -> bool:
	if books.has(id) or not GameDB.all("books").any(func(b: BookDef) -> bool: return b.id == id):
		return false
	books.append(id)
	return true


func has_tool(id: String) -> bool:
	return tools.has(id)


## False when you already own it (a Kitchen Tool is never held twice).
func add_tool(id: String) -> bool:
	if id == "" or tools.has(id):
		return false
	tools.append(id)
	return true
