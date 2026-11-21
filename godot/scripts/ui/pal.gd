class_name Pal
## Market Street UI palette (GDD §7.1), same values as the old style.css :root.
## Sizes use EM: the web UI was sized in em with 1em ≈ 1.55% of the window height,
## so at the 1080p base resolution 1 em ≈ 16.74 px.

const EM := 16.74

const INK := Color("#3b2414")
const INK_SOFT := Color("#6b4a32")
const CREAM := Color("#fbf3e2")
const PAPER := Color("#f3e3c4")
const RED := Color("#d8342c")
const RED_DARK := Color("#a8231d")
const ORANGE := Color("#e07b28")
const GOLD := Color("#f2b632")
const BLUE := Color("#3f7fae")
const GREEN := Color("#4d9a4a")
const LAVENDER := Color("#ece6f6")
const PURPLE := Color("#8a3fb0")
const TIP_BG := Color("#2e1d10f2")
const TIP_TEXT := Color("#fbefd9")
const MODAL_DIM := Color("#2a1a0ccc")

## Ingredient tag colors (cards, tiles, book chips).
const TAG := {
	PROTEIN = Color("#e9a23b"),
	CARB = Color("#c98c4a"),
	VEGGIE = Color("#5ea44f"),
	FAT = Color("#e6c84a"),
	DAIRY = Color("#8fb3d1"),
	SPICE = Color("#d8342c"),
	SAUCE = Color("#9a4a2a"),
	technique = Color("#7c63b5"),
}


static func em(n: float) -> float:
	return n * EM


static func tag_color(tag: String) -> Color:
	return TAG.get(tag, TAG.technique)


static func hex(c: Color) -> String:
	return "#" + c.to_html(false)
