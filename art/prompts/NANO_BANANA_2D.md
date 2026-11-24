# FINALE — Nano Banana prompts for 2D assets

Prompts for making **card frames, card illustrations, modifiers and an icon pack** with Nano Banana
(Gemini image). The style follows the pixel-card reference image ("Archons Exile") and `ART_DIRECTION.md`:
chunky pixel art, dark outlines, a cream frame, a dark body, a teal cost block, the "Market Street" palette.

The explanations are written for humans; the **prompts are in English** (Nano Banana results are more stable that way).
Data used: `godot/data/cards`, `godot/data/modifiers`, `godot/data/recipes`, `godot/assets/icons`,
`scripts/ui/pal.gd`.

---

## 0. How to use (read first)

1. **One style key first.** Make the Ingredient card frame (§2.1) until it is right. That image becomes the **reference image**
   uploaded with every following prompt, plus the "Archons Exile" image. Add the sentence:
   `Match the exact pixel style, outline weight and palette of the attached reference image.`
2. **No text in the image.** Names, costs, numbers and descriptions are drawn by Godot (`card_view.tscn`). Nano Banana
   often misspells, so every prompt asks for **empty** text areas.
3. **A flat background.** Nano Banana does not make transparent PNGs. Every prompt asks for a **flat magenta
   `#FF00FF`** background, which is then removed (magic wand / `rembg` / a script). Magenta is not in the palette, so it is safe.
4. **Sheets, not singles.** Icons and illustrations are made in a grid (2×2, 3×3, 4×4). One sheet = a uniform style.
   Cut it per cell afterward.
5. **Downscale to the real pixel grid.** Nano Banana output is ±1024 px and its "pixels" are uneven. Shrink with
   **Nearest Neighbor** to the art size (table below), then tidy up a little in Aseprite/LibreSprite
   (stray pixels, broken outlines). Optional: quantize to the §1.2 palette.
6. Save to `godot/assets/pixel/<category>/<name>.png`, import with `Filter: Nearest`, `Mipmaps: off`.

| Asset | Prompt aspect ratio | Final art size |
|---|---|---|
| Card frame / back | 3:4 | 48×64 (or 96×128 if the card is scaled ×2) |
| Card illustration | 1:1 (2×2 sheet) | 32×32 per cell |
| Modifier chip | 1:1 | 24×24 |
| Modifier emblem | 1:1 (3×3 / 2×2 sheet) | 16×16 per cell |
| HUD / status / tag icon | 1:1 (4×4 sheet) | 12×12 or 16×16 per cell |
| Dish icon | 1:1 (4×4 sheet) | 24×24 per cell |

> An honest note: 12×12 icons almost always need hand cleanup after downscaling. If that is too much trouble, use
> 16×16 and let Godot scale it.

---

## 1. Style blocks (paste at the start of every prompt)

### 1.1 STYLE
```
Chunky retro pixel art game asset, low resolution look (like a 48x64 sprite scaled up with nearest neighbor),
crisp hard square pixels, no anti-aliasing, no gradients, no blur, no dithering noise, flat shading with
1 highlight and 1 shadow tone per color, 1-pixel dark brown-black outline (#1e1410) around every shape,
limited warm palette. Front-facing, centered, orthographic, no perspective. Clean game UI asset for a
cooking-show deckbuilder. Plain flat solid magenta background (#FF00FF), nothing else in the background.
No text, no letters, no numbers, no watermark, no signature.
```

### 1.2 PALETTE (add it if the colors drift)
```
Use only this palette: wood #2a1a10 #3b2414 #5a3722 #7a4e30 #9c6a42; paper #fbf3e2 #f3e3c4 #d9c39a;
card rim #d9cdb8; card body #241d19; teal #2f6f7a #3f7fae #8fb3d1; hot #d8342c #a8231d #e07b28 #f2b632;
green #4d9a4a #5ea44f #2e5e2c; purple #8a3fb0 #7c63b5; ink #1e1410 #6b4a32; white #ffffff.
```

### 1.3 Ingredient tag colors (from `pal.gd`)

| Tag | Color | Used for |
|---|---|---|
| PROTEIN | `#e9a23b` | art background, pip, icon |
| CARB | `#c98c4a` | |
| VEGGIE | `#5ea44f` | |
| FAT | `#e6c84a` | |
| DAIRY | `#8fb3d1` | |
| SPICE | `#d8342c` | |
| SAUCE | `#9a4a2a` | |
| Technique | `#7c63b5` (art window `#2f6f7a`) | |
| Signature | gold rim `#f2d27a`, art `#4a2a3a` | |

---

## 2. Card frames

The layout follows Card v2 in `card_view.gd` and the reference: a thick cream rim, a dark body, a **teal cost block at the top
left**, a **name ribbon** on top, an **art window** in the middle, a pip column on the side, a **Quality bar** at the bottom.
All slots are empty; Godot fills them.

### 2.1 Ingredient frame (the style key, make this first)
```
[STYLE]
A single empty trading card frame, portrait 3:4, filling most of the image.
Thick light cream rim (#d9cdb8) with slightly chipped pixel corners and a 1px dark outline, small notch
in the middle of the bottom edge. Inside the rim a dark charcoal-brown card body (#241d19).
Top-left: a small square cost block in teal (#2f6f7a) with a lighter inner bevel, EMPTY (no number).
Top: a wide flat name banner in pale cream (#e9dcc6) next to the cost block, EMPTY (no text).
Middle: a large rectangular art window with a dark bevelled inner border, filled with plain flat
mid-grey (#6b6b6b) as a placeholder.
Left edge beside the art window: a small dark tab holding 2 empty round pip sockets.
Bottom: one long empty horizontal bar slot, dark with a thin cream border, divided into 3 segments.
Small empty dark text box under the art window.
Symmetrical, clean, readable at tiny size.
```

### 2.2 Technique frame
```
[STYLE]
Same card frame layout as the attached reference card (cost block top-left, name banner, art window,
side pip tab), but a TECHNIQUE card: the art window is filled with flat teal (#2f6f7a), the side tab
and banner trim use muted purple (#7c63b5) accents, and there is NO bottom bar slot; instead the
empty text box is taller. Cream rim (#d9cdb8), dark body (#241d19). All slots empty, no text.
```

### 2.3 Signature frame (rare)
```
[STYLE]
Same card frame layout as the attached reference card, but a legendary SIGNATURE DISH card:
the rim is warm gold (#f2d27a with #f2b632 highlights), a small pixel crown ornament sits on top of the
rim center, tiny sparkle pixels (#ffffff) on two corners, the name banner is gold (#f2b632),
the art window is filled with deep plum (#4a2a3a). Cost block stays teal. All slots empty, no text.
```

### 2.4 Card back
```
[STYLE]
The back side of a playing card, portrait 3:4, same cream rim (#d9cdb8) and dark body (#241d19)
as the attached reference card. Center emblem: a crossed chef knife and wooden spoon over a round
copper frying pan, in cream and orange (#e07b28), framed by a simple diamond border.
Small repeating checker pattern of two dark browns (#241d19, #3b2414) behind the emblem.
Symmetrical. No text.
```

### 2.5 Tag variants (optional, image edit)
Upload the §2.1 frame, then:
```
Edit this card frame: recolor only the side pip tab and the thin trim around the art window to {TAG COLOR},
and fill the art window with a darker shade of {TAG COLOR}. Keep everything else pixel-identical.
```
Replace `{TAG COLOR}` with a color from §1.3 (e.g. `VEGGIE green #5ea44f`).

---

## 3. Card illustrations (fill the art window, 32×32)

A style like the sword in the reference: one big object in the center, slightly tilted, a dark outline, and the window background
given a faint dot/particle pattern. **The background stays magenta** so it can be cut out; the window color already comes from the frame.

2×2 sheet template:
```
[STYLE]
A 2x2 sprite sheet of 4 separate food illustrations for card art, each centered in its own equal square
cell, generous empty margin, cells separated by plain magenta (#FF00FF). Each object is big, bold,
slightly tilted (about 15 degrees), with a 1px dark outline, 3-4 tones per color and one small white
shine pixel. Same scale and lighting (light from top-left) in every cell.
Top-left: {A}. Top-right: {B}. Bottom-left: {C}. Bottom-right: {D}.
```

| Sheet | {A} | {B} | {C} | {D} |
|---|---|---|---|---|
| **Protein** | raw marbled beef steak, red with white fat streaks | raw chicken drumstick, pale pink with bone end | white fish with blue-grey scales and tail | a single brown egg, slightly cracked |
| **Carb** | a loaf of crusty bread, golden brown | a bundle of dry spaghetti tied with a string | a small bowl of white rice | a pot of steaming water with pasta (spare) |
| **Veggie / Fat** | ripe red tomato with green leaves | a cut purple onion showing rings | a brown button mushroom | a stick of yellow butter on a small dish |
| **Dairy / Spice / Sauce** | a wedge of yellow cheese with holes | a red chili pepper with green stem | a garlic bulb with one clove apart | a glass jar of red tomato sauce |
| **Sauce 2 + spares** | a small pot of golden broth stock with steam | an empty cutting board (spare) | a whisk (spare) | a salt shaker (spare) |

Techniques (a teal window background, so the objects use light colors):
```
[STYLE]
A 2x2 sprite sheet of 4 cooking-show TECHNIQUE illustrations for card art, each centered in its own equal
square cell, cells separated by plain magenta (#FF00FF). Bold, dynamic, readable at 32x32.
Top-left: QUICK CHOP — a cleaver mid-swing chopping a carrot, motion lines, flying pieces.
Top-right: FLAMBE — a frying pan with a tall orange-yellow flame burst (#e07b28, #f2b632).
Bottom-left: DEEP BREATH — a calm chef hat with soft blue (#8fb3d1) breath swirls around it.
Bottom-right: STARE DOWN — two narrowed glaring eyes under a frowning brow, small sweat drop.
```
```
[STYLE]
A 2x2 sprite sheet of 4 cooking-show TECHNIQUE illustrations, same rules as before.
Top-left: MISE EN PLACE — three small prep bowls with chopped ingredients lined up neatly.
Top-right: CROWD PLEASER — a microphone with hearts and stars popping out.
Bottom-left: SIGNATURE DISH — a golden serving cloche lifted with light rays and sparkles.
Bottom-right: spare — a chef's knife crossed with a wooden spoon.
```

File names: `godot/assets/pixel/card_art/<card_id>.png` (`beef`, `chicken`, `fish`, `egg`, `bread`, `pasta`,
`rice`, `tomato`, `onion`, `mushroom`, `butter`, `cheese`, `chili`, `garlic`, `tomatoSauce`, `stock`,
`quickChop`, `flambe`, `deepBreath`, `stareDown`, `miseEnPlace`, `crowdPleaser`, `signature`).

---

## 4. Modifiers (Chef's Flow)

The 10 modifiers from `MODIFIERS.md`. Each modifier = a **chip** (a frame per rarity) + an **emblem** (a unique icon).
For now the HUD uses generic icons (`heat`, `check`, ...); these emblems replace them.

### 4.1 Chip / frame (2 rarities)
```
[STYLE]
Two small square badge frames side by side, each in its own cell, separated by magenta (#FF00FF),
for power-up modifiers in a card game. Each badge: rounded-square pixel frame, dark body (#241d19)
with an EMPTY center for an icon, a small empty circle socket on the bottom-right corner for a stack number.
Left badge COMMON: cream rim (#d9cdb8) with a teal (#2f6f7a) inner line.
Right badge RARE: gold rim (#f2b632) with a purple (#8a3fb0) inner line and two tiny white sparkle pixels.
No text, no icon inside.
```

### 4.2 Modifier pick card (the FlowPick overlay, optional)
```
[STYLE]
A tall reward card frame, portrait 3:4, for choosing a power-up. Cream paper body (#fbf3e2) like an
order ticket, torn zig-zag top edge, a round empty emblem socket in the upper third, a small ribbon
banner below it (EMPTY), and an empty text area at the bottom. A thin colored stripe on the left edge
in teal (#2f6f7a). No text.
```
Rare variant: `...stripe in gold (#f2b632) and a small purple (#8a3fb0) gem at the top.`

### 4.3 Modifier emblems (3×3 sheet, the 9th cell is a spare)
```
[STYLE]
A 3x3 sprite sheet of 9 bold power-up emblems for a cooking card game, each centered in its own equal
square cell, cells separated by plain magenta (#FF00FF). Each emblem is a single simple silhouette that
reads at 16x16 pixels, thick 1px dark outline, 2-3 tones, one white shine pixel. Same scale in every cell.
Row 1:
 1 HOT PAN — a black frying pan glowing red-hot with small flames on the rim.
 2 STEADY HANDS — two open chef hands with a soft blue (#8fb3d1) shield glow.
 3 ENCORE — a gold star with a small "plus" spark, like a bonus star.
Row 2:
 4 EXTRA BURNER — a stove burner ring with an extra blue-orange flame.
 5 PREP COOK — a small stack of three cards with a chef hat on top.
 6 CROWD FAVORITE — a raised hand-clap with tiny hearts.
Row 3:
 7 SPICE WHISPERER — a red chili pepper with a small speech-swirl breath.
 8 FREE MOVE — a curved double arrow looping between two small card shapes.
 9 spare — a wooden spoon.
```
```
[STYLE]
A 2x2 sprite sheet of RARE power-up emblems, same rules, each with a faint gold (#f2b632) aura of pixels.
Top-left: MISE MASTER — three tidy prep bowls with a small gold crown above.
Top-right: PLATING PRO — tweezers placing a leaf garnish on a plate, with two sparkles.
Bottom-left: spare — a gold chef hat.
Bottom-right: spare — a purple gem.
```

File names: `godot/assets/pixel/modifiers/<id>.png` (`hot_pan`, `steady_hands`, `encore`, `extra_burner`,
`prep_cook`, `crowd_favorite`, `spice_whisperer`, `free_move`, `mise_master`, `plating_pro`).

---

## 5. Icon pack

Replaces the SVGs in `godot/assets/icons` (the file names stay the same so the code does not change). The icons are small,
read at 12–16 px, so every prompt asks for a **thick silhouette** with no fine detail.

General rules, pasted after STYLE:
```
Tiny game UI icons. Each icon is one bold, instantly readable silhouette that must still read at
12x12 pixels: no thin lines, no small details, max 3 colors plus outline, thick 1px dark outline.
Each icon centered in its own equal square cell, cells separated by plain magenta (#FF00FF).
All icons same visual weight and size.
```

### 5.1 Ingredient tags (3×3 sheet)
```
[STYLE] [ICON RULES]
A 3x3 icon sheet of ingredient category icons:
Row 1: PROTEIN — a meat drumstick (#e9a23b). CARB — a slice of bread (#c98c4a). VEGGIE — a green leaf (#5ea44f).
Row 2: FAT — a butter stick / oil drop (#e6c84a). DAIRY — a milk bottle (#8fb3d1). SPICE — a red chili (#d8342c).
Row 3: SAUCE — a sauce bottle / ladle drip (#9a4a2a). TECHNIQUE — a chef knife (#7c63b5). spare — a salt shaker.
```
Files: `PROTEIN`, `CARB`, `VEGGIE`, `FAT`, `DAIRY`, `SPICE`, `SAUCE`, `technique`.

### 5.2 Stats & resources (3×3 sheet)
```
[STYLE] [ICON RULES]
A 3x3 icon sheet of battle stat icons:
Row 1: HEAT — an orange flame (#e07b28). HYPE — a lightning bolt in gold (#f2b632). COMPOSURE — a blue shield (#3f7fae).
Row 2: CONFIDENCE — a red heart with a chef hat notch (#d8342c). PRESSURE — a downward fist / impact burst (#a8231d). QUALITY — a gold star (#f2b632).
Row 3: SERVE — a silver serving cloche. DRAW — a card with an up arrow. DISCARD — a card with a down arrow into a bin.
```
Files: `heat`, `hype`, `composure`, `confidence`, `pressure`, `quality`, `serve`, `draw`, `discard`.

### 5.3 Statuses (3×3 sheet)
From `status_defs.gd`: spicy, flustered, rattled, burnt (debuffs); focus, inspired (buffs).
```
[STYLE] [ICON RULES]
A 3x3 icon sheet of status effect icons. Debuffs have a thin red (#d8342c) corner mark, buffs a thin green (#4d9a4a) corner mark.
Row 1: SPICY — a red chili with heat waves. FLUSTERED — a spiral dizzy face swirl in pink-red. RATTLED — a shaking cracked plate.
Row 2: BURNT — a black burnt smoking pan with grey smoke. FOCUS — an eye inside a target ring (teal #2f6f7a). INSPIRED — a light bulb with sparkles (gold).
Row 3: BUFF — an up arrow (green). TAUNT — an angry speech bubble with an exclamation mark. spare — a sweat drop.
```
Files: `spicy`, `flustered`, `rattled`, `burnt`, `focus`, `inspired`, `buff`, `taunt`.

### 5.4 General UI (3×3 sheet)
```
[STYLE] [ICON RULES]
A 3x3 icon sheet of general UI icons:
Row 1: CHECK — a bold green check mark. CROWN — a small gold crown. ARROW — a thick right arrow.
Row 2: BOOK — a closed recipe book with a bookmark. TIPS — a question mark in a round bubble. SETTINGS — a gear.
Row 3: LOCK — a padlock. CLOSE — a bold X. PLAY — a right-pointing triangle.
```
Files: `check`, `crown`, `arrow`, `book`, `tips`, `settings`, `lock`, `close`, `play`.

### 5.5 Cooking methods (ticket, 2×2 sheet)
```
[STYLE] [ICON RULES]
A 2x2 icon sheet of cooking method icons for an order ticket:
Top-left: FRY — a frying pan with oil drops. Top-right: GRILL — a grill grate with flame under it.
Bottom-left: BOIL — a pot with bubbles and steam. Bottom-right: RAW — a cutting board with a knife.
```
Files: `method_fry`, `method_grill`, `method_boil`, `method_raw`.

### 5.6 Dish icons (13 recipes, 4×4 sheet, 24×24)
```
[STYLE]
A 4x4 sprite sheet of 16 finished dish icons for a cooking game, each plated on a small round
white-cream plate (#fbf3e2) seen from a 3/4 top angle, centered in its own equal square cell,
cells separated by plain magenta (#FF00FF). Bold readable shapes, 1px dark outline, appetizing warm colors.
Row 1: toast with butter; folded omelette with green herbs; fresh green salad bowl; classic steak with garlic.
Row 2: two meat skewers; mixed grill platter; arrabbiata penne in red sauce; hot chicken wings in red glaze.
Row 3: warm soup bowl with steam; mac and cheese; mushroom risotto; tall burger with cheese and lettuce.
Row 4: sandwich cut diagonally; spare: empty plate; spare: covered cloche; spare: burnt black dish with smoke.
```
Files: `godot/assets/pixel/dishes/<recipe_id>.png` (`toast`, `omelette`, `freshSalad`, `classicSteak`, `skewers`,
`mixedGrill`, `arrabbiata`, `hotWings`, `warmSoup`, `macAndCheese`, `mushroomRisotto`, `burger`, `sandwich`).
The "burnt dish" cell can be used for the Improvised result.

---

## 6. Fix prompts (when the result misses)

| Problem | Add / resend |
|---|---|
| Too smooth, looks like a painting | `Strictly pixel art. Every pixel is a visible hard square. No soft shading, no gradients, no painterly texture.` |
| Pixels are not a uniform size | `All pixels must be the same size on one uniform grid, as if drawn at 32x32 and scaled up 32x.` |
| Text / letters appear | `Remove all text and letters. Leave the banner and boxes completely empty.` |
| The background is uneven / has a shadow | `Background must be one flat solid #FF00FF with no shadow, no gradient, no floor.` |
| The style differs between sheets | Upload a sheet that is already good + `Match the exact style, outline and scale of the attached sheet.` |
| Colors outside the palette | Paste the PALETTE block §1.2 |
| Icons too detailed | `Simplify to a chunky silhouette readable at 12x12. Remove small details.` |

---

## 7. Production checklist

- [ ] The Ingredient frame (the style key) is approved
- [ ] Technique frame, Signature, card back
- [ ] 5 ingredient illustration sheets + 2 technique sheets
- [ ] Common/Rare modifier chips + 2 modifier emblem sheets
- [ ] Icon pack: tags, stats, statuses, UI, methods, dishes
- [ ] Everything downscaled with Nearest, the magenta background removed, saved in `godot/assets/pixel/...`
- [ ] Hooked up in Godot: `card_view.tscn` (frame + `%ArtIcon`), modifier chips in `duel_ui.tscn`, `Ui.icon_tex()`
