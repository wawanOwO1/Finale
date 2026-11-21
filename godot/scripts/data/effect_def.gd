class_name EffectDef
extends Resource
## One composable effect (GDD §9). Cards, recipes and later Kitchen Tools all use a list of these.
## `amount` is the base value; recipes add the Plate's total Quality to their FIRST effect.

enum Kind { PRESSURE, COMPOSURE, HEAL, DRAW, HYPE, STATUS, CLEANSE }
## Seen from the player: ENEMY = the rival, SELF = Apis.
enum Target { ENEMY, SELF }

@export var kind: Kind = Kind.PRESSURE
@export var amount := 0
## Only for Kind.STATUS.
@export_enum("spicy", "flustered", "rattled", "burnt", "focus", "inspired") var status := "spicy"
## Only for Kind.STATUS.
@export var target: Target = Target.ENEMY


static func make(kind_: Kind, amount_: int, status_ := "spicy", target_ := Target.ENEMY) -> EffectDef:
	var e := EffectDef.new()
	e.kind = kind_
	e.amount = amount_
	e.status = status_
	e.target = target_
	return e
