class_name StatusDefs
## Statuses (GDD §4.7). Every status has a tooltip; X = stacks.

const ALL := {
	"spicy": {
		name = "Spicy", debuff = true,
		text = "Loses X Confidence at the start of its turn, ignoring Composure. Then X goes down by 1.",
	},
	"flustered": {
		name = "Flustered", debuff = true,
		text = "Deals 25% less Pressure. Lasts X turns.",
	},
	"rattled": {
		name = "Rattled", debuff = true,
		text = "Takes 50% more Pressure. Lasts X turns.",
	},
	"burnt": {
		name = "Burnt", debuff = true,
		text = "The next X Serves have 50% less effect.",
	},
	"stumped": {
		name = "Stumped", debuff = true,
		text = "Never tasted that dish before. Starts the next turn with X less Heat.",
	},
	"focus": {
		name = "Focus", debuff = false,
		text = "Adds X Pressure to every attack. Lasts the whole duel.",
	},
	"inspired": {
		name = "Inspired", debuff = false,
		text = "Draw X more cards next turn.",
	},
}

## Order Fresh Salad's cleanse removes debuffs in: the most harmful first.
const CLEANSE_ORDER: PackedStringArray = ["burnt", "spicy", "rattled", "flustered"]


static func display_name(id: String) -> String:
	return ALL[id].name if ALL.has(id) else id.capitalize()


static func is_debuff(id: String) -> bool:
	return ALL.has(id) and ALL[id].debuff
