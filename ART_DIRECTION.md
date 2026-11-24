# FINALE — Art Direction & Grand Design (v0.1)

> Companion to [GDD.md](GDD.md). Replaces **GDD §7.1–7.3** (visuals & HUD) and proposes changes to **GDD §4.2–4.3** (Plate → ordered Station Stack). Written 22 Nov 2026.
> All reference images are **guidance for feel and structure only**. No assets, characters or layouts are copied.

---

## 0. Brief confirmation

| # | Reference | What is taken for Finale | What is **not** taken |
|---|---|---|---|
| 1 | A pixel card duel on a wooden table | Chunky pixel art, a limited warm palette, cream cards with colored corners, the wooden table as a "stage", small ribbon labels | The goblin/undead characters, the 2-row card layout, the action buttons |
| 2 | HUD UI kit (shark) | The shape language: diamond badges for portraits, curved bars, slanted ribbons, dark-cream number chips, red/orange/teal/mustard accents | Its icons and illustrations |
| 3 | Gauge shape catalog | **#08/#09 arc** for Confidence, **#13 segmented** for Hype, **#11 diamond** for the intent timer, **#14 number inside** | The neon blue style |
| 4 & 5 | Eye/face expressions | Emote pop-ups beside the opponent's head: smug, angry, sad, etc. | — |
| 6 | "ROUND 3 / FIGHT!" | Big-text announcer: countdown → ROUND N → FIGHT!, then FINISHED → result | Its original font |
| 7 | A burger ticket + ingredient icons | An **Order Ticket** above the stack: dish icon + required ingredient icons, checked off as they are filled, a cooking-method icon | — |
| 8 | A stacked 2048 solitaire | Ingredients **stacked vertically** per column, several columns at once | The 2048 number rules |

**Additional confirmed details**
- Recipes have an **order like in the real world** (burger: bun → filling → bun). The order can be simplified, but the logic stays sensible.
- The HUD/UX layout is made first on an **editable canvas**, and only after it is final are the pixel assets made.

---

## 1. Visual pillars

1. **Warm pixel diorama.** A low-poly 3D cooking-show kitchen rendered at low resolution, feeling like hand-made pixel art.
2. **The table is the stage.** Cards, stacks and tickets live on a wooden table, just like ref 1. The HUD feels like physical objects (wooden boards, paper, ribbons), not floating panels.
3. **Faces that talk.** Opponents react through big, clear emotes. The player reads the opponent's "mood" without reading text.
4. **Every moment gets a stamp.** Start, combo, Signature Dish, win, lose: all have announcer text, sound and screen shake.

---

## 2. Pixel rendering pipeline

### 2.1 Base resolution
| Layer | Internal resolution | Scale to 1080p | Notes |
|---|---|---|---|
| 3D world | **640×360** | ×3 | SubViewport, `nearest` filter |
| Pixel UI | **640×360** (art grid) | ×3 | Drawn 1 art px = 3 screen px. Small text uses an 8–11 px pixel font |
| Long text (tooltips, card descriptions) | native | — | May use full resolution with an integer-scaled pixel font, so it stays readable |

640×360 was chosen because it scales by whole numbers at 720p (×2), 1080p (×3) and 1440p (×4). Other sizes use a thin letterbox or the nearest scale.

### 2.2 Shader from `leopeltola/Godot-3d-pixelart-demo`
Checked: license **MIT** (must be credited). How it works:
- This is an **outline/highlight** shader, not a pixelate shader. The pixel look comes from low-resolution rendering.
- A dark outline from the **depth buffer** (4 neighbors). A bright highlight on edges from the **normal buffer**.
- Parameters: `shadow_strength` (0.4), `highlight_strength` (0.1), `shadow_color`, `highlight_color`, a shadows/highlights toggle.

**⚠️ Technical risk:** this shader was made for **Forward+**, while our project uses **Compatibility** (required for Web export). The normal buffer (`hint_normal_roughness_texture`) does not exist in Compatibility.

**Plan:**
1. Port the shader as a **per-object material** (recommended by its README, since the post-process mode has transparency bugs).
2. Keep the **depth outline** part (`hint_depth_texture` is available in Compatibility).
3. Replace the **normal highlight** part: reconstruct normals from depth, or a simple rim light in the object shader.
4. Our own additions: **palette quantization** (lookup into the 24-color palette, §3) and **camera snapping to texels** so no pixels "swim" when the camera moves.
5. Test in a Web build before mass-producing assets (Phase 2).

Fallback if the depth texture is a problem on Web: an **inverted hull** outline (a slightly larger duplicate mesh, back-face, dark color). Cheap and safe on every renderer.

### 2.3 3D modeling rules
- Low-poly, **flat/vertex color**, no detailed textures. Small details (eyes, logos) use 16–32 px pixel textures.
- Character size on screen: ±60–80 px art tall (at 640×360). Big head (1:3), a readable silhouette.
- Lighting: 1 warm key light + ambient. Hard shadows.

---

## 3. Palette & typography

### 3.1 Palette (24 colors, "Market Street")
Derived from the current `Pal.gd`, shifted toward the wooden-table feel of ref 1.

| Group | Colors |
|---|---|
| Wood (table, HUD boards) | `#2a1a10` `#3b2414` `#5a3722` `#7a4e30` `#9c6a42` |
| Paper (cards, tickets) | `#fbf3e2` `#f3e3c4` `#d9c39a` |
| Ink (text, outlines) | `#1e1410` `#3b2414` `#6b4a32` |
| Hot accents | `#d8342c` `#a8231d` `#e07b28` `#f2b632` |
| Cool accents | `#2f6f7a` (teal) `#3f7fae` `#8fb3d1` |
| Nature | `#4d9a4a` `#5ea44f` `#2e5e2c` |
| Special | `#8a3fb0` (Signature) `#ffffff` (shine) `#000000` (shadow) |

Ingredient tag colors stay as in `Pal.TAG` (PROTEIN orange, VEGGIE green, etc.) and are used on the **card corners**, like the colored triangles in ref 1.

### 3.2 Fonts (all freely licensed, re-check when installed)
| Use | Candidate | Style |
|---|---|---|
| Announcer (ROUND, FIGHT!, FINISHED) | a bold condensed pixel font, e.g. *Pixel Operator Bold* (CC0) scaled ×4–×6 | Cream `#fbf3e2` with a 2 px ink outline + shadow |
| Big numbers (HP, card cost) | same, ×2 | Bold numbers like the "11" in ref 1 |
| UI text & tooltips | *m5x7 / m6x11* (Daniel Linssen, free with credit) | Small, tidy |

---

## 4. HUD layout (wireframe, to be iterated on the canvas)

> Editable canvas: [Finale HUD Layout](https://claude.ai/artifact/2LPfQEPSEpKToxQ2iBWAqF). It contains the Duel HUD, HUD Kit, Station Stack, Emotes and 4 announcer screens. That canvas is the main reference, the text wireframe below is only a summary.

Art grid 640×360. Numbers = approximate position in art px.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [ROUND 2/5]            ╔═ HYPE ▮▮▮▮▯▯▯▯▯▯ ═╗              [⚙] [📖]        │ y 0–24
│                                                                              │
│                         ◇ Tony  ◠◠◠◠ 24/30 ◠                                 │
│                           [intent ◆ 8]   (😏 emote)                          │
│                              🧑‍🍳 RIVAL (3D)                                   │ y 24–150
│ ┌ STATION 1 ┐ ┌ STATION 2 ┐ ┌ STATION 3 ┐                                    │
│ │ 🎫 ticket │ │ 🎫 ticket │ │ 🎫 ticket │      🧑‍🍳 APIS (3D)                  │
│ │ [Bread  ] │ │ [Butter ] │ │           │                                    │
│ │ [Beef   ] │ │ [Egg    ] │ │  + drop   │                                    │
│ │ [Cheese ] │ │           │ │           │                                    │
│ │ [SERVE 1🔥]│ │ [SERVE  ] │ │           │                                    │ y 150–270
│ └───────────┘ └───────────┘ └───────────┘                                    │
│ ◇APIS ◠◠◠◠◠ 48/60   🔥🔥🔥 Heat      [hand: ▭ ▭ ▭ ▭ ▭]   [Draw 12][Disc 3][END]│ y 270–360
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Components
| Component | Shape (ref) | Detail |
|---|---|---|
| **Player portrait** | Cream diamond (ref 2) | Bottom left, ±40 px. Small status icons above it |
| **Player Confidence** | Arc gauge (ref 3 #08) beside the diamond | Red, with a white shiny tip (ref 2). Number inside the bar (#14). The Composure part = a blue layer over the arc |
| **Opponent Confidence** | A small arc above the head + a small diamond | Follows the 3D head position |
| **Opponent Intent** | Diamond (ref 3 #11) | Action icon + number. A 2-turn Intent: the diamond is half filled |
| **Heat** | 3 flame pips | Empty pip = grey, filled = orange with a slow blink |
| **Hype** | A 10-segment bar (ref 3 #13) at the top center | Full = a gold ribbon + shine, the Signature card appears |
| **Round** | A "ROUND 2 / 5" chip (ref 2) | Top left. 5 = the number of duels in Market Street |
| **Station** | A vertical wooden board + a ticket above | See §6 |
| **Hand** | Cream cards, a thin fan | Cost at top left, colored tag corner, name ribbon on hover (the "Plague Rat" ribbon in ref 1) |
| **Draw / Discard** | Physical card piles on the table (ref 1) | Number in a dark chip |
| **End Turn** | A slanted red ribbon | Bottom right |

### 4.2 UX principles
- Everything draggable has a **shadow** and lifts slightly on hover.
- **Drop targets** (stations) light up when a matching card is dragged. A faint red if it is a wrong step (§6.3).
- Opponent information is always **on top**, the player's always **at the bottom**.
- 1080p target: clickable elements are at least 16×16 art px (48 screen px).

---

## 5. Opponent emotes

A pop-up **beside the opponent's head** (upper right of the head), in a 24×24 art-px cream bubble with a small tail. A simple face style: eyes + mouth only, following refs 4 & 5.

| State | Trigger | Emote | Animation |
|---|---|---|---|
| **Smug** (arrogant laugh) | Player Confidence ≤ 30% | Eyes `^ ^`, wide mouth, a small "HA HA" | The bubble bounces 2×, the chef shakes with laughter |
| **Angry** | Opponent Confidence ≤ 25% (dying) | Slanted brows `\ /`, zigzag mouth, a "💢" vein | The bubble trembles, flashes red |
| **Sad** | The opponent loses | Eyes `T T` / `; ;`, a downturned mouth | The bubble slowly sinks, the chef bows their head |
| **Shocked** | Hit by a recipe Serve ≥ 15 Pressure or the Signature | Round eyes, an "O" mouth | A quick pop, shake |
| **Confident** | The opponent sets up a big Intent (2 turns) | One winking eye `> ●` | Appears together with the Intent |
| **Tired** (optional) | The opponent gets Flustered | Eyes `- -`, sweat | — |

**Rules:** at most 1 emote at a time. Duration 1.5 seconds, except **Angry**, which stays as a small (mini icon) while the opponent is dying. Priority: Sad > Shocked > Angry > Smug > Confident. Smug and Angry appear **once per threshold crossing**, so there is no spam.

Each emote is a 24×24 sprite (2–4 frames). One set is used by all chefs; a chef may have their own bubble color.

---

## 6. Station Stack & ordered recipes (Grand Design proposal)

> This is a **gameplay** change, not only a visual one. It replaces the 5-slot Plate in GDD §4.2–4.3.

### 6.1 Rules
- There are **3 Stations** (columns) on the table. Each station stacks ingredients **like solitaire**: the first ingredient is at the very top of the column, each new ingredient overlaps downward. Older cards show only a name ribbon + tag icon, the newest card is fully visible (gold frame = can be taken). Maximum **6** (7 with *Bigger Plate*).
- Ingredients from the hand are dragged onto the **top** of any stack. Only the top card can be touched (like solitaire).
- A stack **persists between turns**, like the current Plate. The player can prepare 2–3 dishes at once.
- **Serve** picks 1 station (1 Heat, once per turn). That station is empty again.
- **Move the top card** to another station: 1× per turn, free. This gives room to fix a stacking mistake.
- **Clear station**: discard the whole stack, free, ends that turn's chance to move.

### 6.2 Matching
A recipe has an **order of steps**. A station is read from the first card (top of the column) to the newest card (bottom of the column). In the §6.4 table, "bottom → top" means this placement order.

| Result | Condition | Effect |
|---|---|---|
| **Perfect** | Stack = the exact recipe order | Recipe effect ×1.5 (the existing Perfect Order) |
| **Cooked** | All recipe ingredients present but a different order | Recipe effect ×1.0 |
| **Garnish** | Extra ingredients **on top of** an already complete recipe | +1 Quality per ingredient, max +2 |
| **Improvised** | Matches no recipe | 2 × number of ingredients in Pressure (the old rule) |

> **Decided 22 Nov:** the **soft** rule (Perfect/Cooked) is used. A mandatory order is not used.

### 6.3 Order Ticket (ref 7)
- As soon as the first card enters a station, the ticket above it shows the **most likely recipe**: a dish icon + a row of ingredient icons in order + a cooking-method icon (pan, grill, boil).
- Ingredients already there = a bright icon + a checkmark. The next step = blinking.
- If the stack goes off track, the ticket becomes "???" (Improvised) in grey.
- When the recipe is complete: the ticket **"stamps"** PERFECT!/COOKED with a stamp animation, gold ticket corners.
- **Decided 22 Nov:** the ticket **may give hints** about the recipe. This replaces the GDD rule "the Recipe Book is closed during a duel, no recipe hints".

### 6.4 Recipe order (draft, real world simplified)
Key: `TAG` = any ingredient with that tag, *Name* = a key ingredient.

| Recipe | Order (bottom → top) | Kitchen logic |
|---|---|---|
| Toast | `CARB` → `FAT` | Bread, then spread butter |
| Omelette | `FAT` → *Egg* → `VEGGIE` | Heat the butter, pour in the egg, add vegetables |
| Fresh Salad | `VEGGIE` → `VEGGIE` (→ `FAT` garnish) | Vegetables, vegetables, dressing |
| Classic Steak | `FAT` → *Beef* → `SPICE` | Oil in the pan, sear the meat, garlic basting |
| Skewers | `PROTEIN` → `SPICE` | Skewer the meat, season |
| Mixed Grill | `FAT` → `PROTEIN` → `PROTEIN` | Oil, meat, meat |
| Arrabbiata | `SPICE` → `SAUCE` → `CARB` | Sauté chili/garlic, tomato sauce, add the pasta |
| Hot Wings | *Chicken* → `SPICE` → `SPICE` | Chicken, seasoning, seasoning |
| Warm Soup | `VEGGIE` → `PROTEIN` → `SAUCE` | Sauté vegetables, meat, pour in stock |
| Mac & Cheese | *Pasta* → `FAT` → `DAIRY` | Boil the pasta, butter, cheese |
| Mushroom Risotto | *Rice* → *Mushroom* → `DAIRY` | Rice, mushrooms, cheese/cream |
| **Burger** (new, Grill) | *Bread* → *Beef* → *Cheese* → `VEGGIE` → *Bread* | Showcase for a tall stack (5) |
| **Sandwich** (new, Basics) | *Bread* → `PROTEIN` → `VEGGIE` → *Bread* | An easy burger variant |

The code is partly ready: `RecipeDef.requires` is already ordered and `RecipeMatch.in_order()` already exists. The changes: the Plate becomes 3 arrays, matching per station, the Garnish rule, and the `requires` order in the `.tres` files adjusted to this table.

---

## 7. Match flow & announcer (ref 6)

| Moment | Screen sequence | Duration |
|---|---|---|
| **Duel start** | The camera slowly approaches the table → **3 · 2 · 1** (big numbers, pop + tick SFX) → **ROUND 2** (small, above) **FIGHT!** (big) → cards are dealt | ±3 s |
| **Combo / recipe** | The ticket "stamps" → the dish name on a ribbon → the Pressure number flies up | ±1 s |
| **Signature Dish** | Cut-in (GDD §4.5) + the text **"SIGNATURE!"** | ±2 s |
| **Win** | The opponent's Sad emote → **FINISHED** → **YOU WINS!** → Victory screen | ±3 s |
| **Lose** | The opponent's Smug emote → **FINISHED** → **LOSER** (letters fall one by one, grey-red) → run summary | ±3 s |

"ROUND N" = the Nth duel on the Course Path (Market Street). Win text variations (randomized): *APIS WINS!*, *ORDER UP!*, *CHEF'S KISS!*. The lose text stays **LOSER** for contrast.

Text style: cream with a thick ink outline + drop shadow, slightly slanted, entering with *squash & stretch*. Background: a semi-transparent dark strip across the full screen width (like ref 6).

---

## 8. Asset list (for production once the layout is final)

| Category | Assets | Art size | Count |
|---|---|---|---|
| Cards | Ingredient, technique and Signature card frames; card back | 48×64 | 4 |
| Card illustrations | 1 per ingredient/technique | 32×32 | ±30 |
| Ingredient icons (ticket) | Mini version | 12×12 | ±20 |
| Dish icons | 1 per recipe | 24×24 | 13 |
| Method icons | pan, grill, boil, raw | 12×12 | 4 |
| HUD | Portrait diamond, arc gauge (frame + fill), Hype bar, Heat pips, chips, ribbons, buttons | various | ±15 |
| Station | Wooden board, ticket, PERFECT/COOKED stamp | 56×120 | 4 |
| Emotes | 6 emotes × 2–4 frames + bubble | 24×24 | ±20 frames |
| Announcer | 3/2/1, ROUND, FIGHT!, FINISHED, WINS!, LOSER (or from the font) | — | 6 |
| Portraits | Apis + 5 chefs, diamond version | 40×40 | 6 |
| 3D | Stage, 2 tables, MC, 5 chefs, ±13 dishes | low-poly | — |

File convention: `godot/assets/pixel/<category>/<name>.png`, no filter, imported with `Filter: Nearest`, `Mipmaps: off`.

---

## 9. Decisions

1. ~~Canvas~~ → **HTML canvas in Claude** ([Finale HUD Layout](https://claude.ai/artifact/2LPfQEPSEpKToxQ2iBWAqF)).
2. ~~Order rule~~ → **soft** (Perfect ×1.5 / Cooked ×1.0).
3. ~~Recipe hints~~ → **The Order Ticket may give hints.**
4. ~~Number of stations~~ → **3**, shown as solitaire stacks. *(Later changed to 2 on 23 Nov, see GDD §4.3.)*
5. ~~Name on the win screen~~ → **YOU WINS!** (lose: LOSER).

---

## 10. Masterplan

Submit deadline 18 Dec 2026. First upload 14 Dec.

| Phase | Date | Output | Done when |
|---|---|---|---|
| **0. Brief** | 22 Nov | This document | The §9 decisions are answered |
| **1. Layout on the canvas** | 23–25 Nov | Duel HUD wireframe, Station + ticket, emotes, announcer, win/lose screens | You approve the layout |
| **2. Pixel pipeline test** | 24–26 Nov | The shader ported to Compatibility, 640×360 SubViewport, palette + camera snapping, **Web build test** | A graybox scene looks "pixel" in the browser, ≥45 fps |
| **3. Station Stack (code)** | 25–28 Nov | 3 stations, recipe order, Garnish, moving cards, ticket (graybox), update `.tres` + `sim` tests | A full duel runs with the new rules, tests pass |
| **4. Graybox juice** | 28 Nov–1 Dec | Countdown/FIGHT/FINISHED, emotes (placeholder), ticket stamp | All §7 moments exist, even if still boxy |
| **5. Pixel asset production** | 1–9 Dec | §8 assets per the final layout | No placeholders in the duel |
| **6. 3D assets + characters** | 4–11 Dec | Stage, chefs, dishes with the outline material | Market Street is complete |
| **7. Polish & submit** | 12–18 Dec | Tutorial, audio, 5-resolution tests, upload 14 Dec | Submit |

**Cut if behind (in order):** Tired/Confident emotes → emote frame animation (use 1 frame) → new recipes (Burger/Sandwich) → the 3rd station → camera snapping.

---

## Credits to note
- *Godot-3d-pixelart-demo* by Leo Peltola — MIT.
- The fonts used (per their respective licenses).
