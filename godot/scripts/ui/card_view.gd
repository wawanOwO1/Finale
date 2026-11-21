class_name CardView
extends Button
## One card in hand (or a Plate slot). Layout lives in card_view.tscn.

const TYPE_COLORS := {
	CardDef.Type.INGREDIENT: Color("#f6e7c8"),
	CardDef.Type.TECHNIQUE: Color("#cfe3ec"),
}

var card: CardInstance


func setup(card_: CardInstance, playable: bool) -> void:
	card = card_
	var d := card.def
	%Cost.text = str(d.cost)
	%Name.text = d.name
	%Type.text = ("Ingredient · " + ", ".join(d.tags)) if d.is_ingredient() else "Technique"
	%Text.text = d.text
	disabled = not playable
	%Type.modulate = TYPE_COLORS[d.type]
	tooltip_text = "%s\n%s" % [d.name, d.text]
