class_name Keywords
## Keyword tooltips (GDD §7.3 "tooltip keyword di mana-mana"). Card text highlights these
## words, and hovering a card lists what each one means, Slay-the-Spire style.

const BASE := {
	"Pressure": {icon = "pressure", text = "Hits the rival's Composure first, then their Confidence."},
	"Composure": {icon = "composure", text = "Blocks incoming Pressure. Fades at the start of your turn."},
	"Confidence": {icon = "confidence", text = "A chef at 0 Confidence gives up."},
	"Quality": {icon = "hype", text = "When you Serve a recipe, the board's total Quality is added to its main effect."},
	"Hype": {icon = "hype", text = "The crowd meter. At 100, your Signature Dish appears in hand."},
	"Heat": {icon = "heat", text = "Spent to play cards and to Serve. Refills to 3 each turn."},
	"Draw": {icon = "draw", text = "Take cards from your draw pile."},
	"Retain": {icon = "check", text = "Stays in your hand at the end of the turn."},
	"Serve": {icon = "serve", text = "Cook everything on the Prep Board. Ingredients in Recipe Book order give a Perfect Order (x1.5)."},
}

static var _all := {}
static var _re: RegEx


## name -> { name, icon, text } including every status.
static func all() -> Dictionary:
	if _all.is_empty():
		for k in BASE:
			_all[k] = {name = k, icon = BASE[k].icon, text = BASE[k].text}
		for id in StatusDefs.ALL:
			var s: Dictionary = StatusDefs.ALL[id]
			_all[s.name] = {name = s.name, icon = id, text = s.text}
	return _all


static func _regex() -> RegEx:
	if _re == null:
		_re = RegEx.create_from_string("\\b(%s)\\b" % "|".join(PackedStringArray(all().keys())))
	return _re


## Card text as BBCode with keywords colored.
static func highlight(text: String, color := Pal.ORANGE) -> String:
	return _regex().sub(text, "[color=%s]$1[/color]" % Pal.hex(color), true)


## Keywords that explain a card, in reading order, without duplicates.
static func for_card(def: CardDef) -> Array:
	var names: Array[String] = []
	for m in _regex().search_all(def.text):
		var n := m.get_string(1)
		if not names.has(n):
			names.append(n)
	if def.is_ingredient() and not names.has("Quality"):
		names.append("Quality")
	var out := []
	for n in names:
		out.append(all()[n])
	return out


## The first tooltip line: what this kind of card does when you drag it.
static func card_role(def: CardDef) -> Dictionary:
	if def.special == "signature":
		return {name = "Signature Dish", icon = "crown", text = "Drag up to play. Your next Serve has x2 effect."}
	if def.is_ingredient():
		return {name = "Ingredient", icon = def.first_tag(),
				text = "Drag onto the Prep Board. Order matters: match your Recipe Book."}
	return {name = "Technique", icon = "technique", text = "Drag up out of your hand to play it."}
