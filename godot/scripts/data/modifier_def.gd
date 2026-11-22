class_name ModifierDef
extends Resource
## A Chef's Flow modifier (GRAND_DESIGN §5): picked 1 of 3 after enough Perfect Order Serves,
## lasts the rest of the duel. One .tres per modifier in res://data/modifiers/. What it does
## is coded by `id` in Duel (search "_mods(" there); the numbers live here for the Inspector.

enum Rarity { COMMON, RARE }

@export var id := ""
@export var name := ""
@export var rarity: Rarity = Rarity.COMMON
## Icon name from res://assets/icons (tinted).
@export var icon := "buff"
## Tooltip / pick card text. "X" is replaced by the current amount.
@export_multiline var text := ""
## Picking it again adds a stack (amount × stacks). Non-stackable ones leave the offer once owned.
@export var stackable := true
## Per-stack value (Pressure, Composure, Hype, multiplier step…).
@export var amount := 1.0
## Ingredient tag this modifier is built for ("" = any deck). An offer always holds one that
## fits the deck's build when one exists (GRAND_DESIGN §5.2 rule 2).
@export var tag := ""


func is_rare() -> bool:
	return rarity == Rarity.RARE


## Text with the amount for `stacks` stacks filled in.
func describe(stacks := 1) -> String:
	var v := amount * maxi(1, stacks)
	return text.replace("X", str(int(v)) if is_equal_approx(v, roundf(v)) else str(v))
