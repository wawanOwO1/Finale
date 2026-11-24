# GDD — *FINALE* (working title) · Jam Version

> OpenGame Game Jam #1 · Track: **05 Strategy** (deck-builder) + sponsors **fal**, **ElevenLabs** · Solo
> Upload deadline: **18 Dec 2026, 23:59 PT** (≈ 19 Dec 14:59 WIB) · First upload target: **14 Dec**
> In-game language: **full English** · Tech: **Godot 4.7** (Compatibility renderer, Web export) in `godot/`

> **Updated 24 Nov 2026** to match the code. Big changes from the 18 Nov version: **Godot** replaces Vite/TS/Three.js (the old web version in `src/` is reference only), **Station Stack** replaces the Plate, **rival drafting** replaces Intent, and there are new systems (Chef's Flow, Almanac, fair RNG). Companion docs: [GRAND_DESIGN.md](GRAND_DESIGN.md) (turns, rival AI, RNG, Flow, Almanac), [ART_DIRECTION.md](ART_DIRECTION.md) (visuals, HUD, Station Stack), [MODIFIERS.md](MODIFIERS.md).> Status marks: ✅ in the code · ⏳ not done yet · ✂️ cut.

> **Origin (important for the jam rules):** this design is derived from the older *Cooking Show Deckbuilder* GDD (v0.1, 1 Nov 2026), which contained only documents, references and a paper prototype. There was no code or assets. The jam rules allow reusing **ideas and mechanics**. All code, 3D assets, images and audio are **made from 18 Nov 2026 onward** and logged in git from the first commit as proof of development history. Reference images are used only as guidance for structure and feel, never copied.

---

## 1. Overview

An **over-the-top cooking-anime** roguelike deckbuilder. You are a young chef challenging the city's top chefs to cooking duels. Stack ingredients on a **Station**, complete recipes, and make your opponent lose **Confidence** until they give up.

**Design pillars**
1. **Recipes are combos, and order matters.** Ingredients you play stack on a **Station** like solitaire. An exact match with a recipe's order gives **Perfect Order** (×1.5); the right ingredients in the wrong order is still **Cooked** (×1).
2. **Two layers of deckbuilding.** Deck = the ingredients and techniques you own. **Recipe Book** = what you can cook from them. Both are built during a run.
3. **The opponent plays by the same rules.** The rival has their own deck, hand, Heat and 2 Stations. Their cards are face-down, and nothing is rigged (see §4.9).
4. **Over the top, anime style.** Dramatic reactions, cut-ins, auras, an awestruck crowd. Every recipe Serve must *feel* like a moment.
5. **Small but finished.** One character, one polished district, runs of ±20–30 minutes.

**Tone:** culinary shounen anime. Arrogant rivals, fired-up monologues, exaggerated reactions. Friendly for all ages.

## 2. Setting

- **City:** *Saporé City*, a fictional food city with an international feel.
- **Tournament:** *The Grand Plate*. The jam version contains the first round, **Market Street**, which ends with a duel against *"Iron" Bruno*.
- **Protagonist:** **Apis Tetrarch** ("Apis", placeholder name), a young chef with no reputation from a small family kitchen who wants to become the city's number one chef.
- **Storytelling:** ⏳ a short intro, one or two lines of dialogue before and after each duel (portrait + text box), a VS screen before the boss, and a short ending that teases the next district.

## 3. Core loop

```
Title → New Run (starter deck + Basics Cookbook)                              ⏳
  → Market Street Course Path: each step, pick 1 of 2–3 encounter cards          ⏳
       [Duel | Elite | Shop | Event | Practice Kitchen]
  → Reward → ... (±9 steps) → Practice Kitchen → BOSS: "Iron" Bruno             ⏳
  → Win: ending + run score · Lose: run summary → New Run                       ⏳
```

Right now only **a single duel** works (Apis vs Tony or Rosa), set up through the `Main` node's Inspector (`Enemy Id`, `Dev Deck`, `Start Hype`). The run layer on top of it does not exist yet. There is no meta-progression in the jam version (see §11).

## 4. Duel mechanics ✅

### 4.1 Stats
| Stat | Function |
|---|---|
| **Confidence** (HP) | The chef's morale. 0 = gives up. Apis starts at **100** (`Duel.PLAYER_CONFIDENCE`), carried between duels. |
| **Composure** (Block) | Absorbs Pressure. Reset at the start of its owner's turn. |
| **Heat** (Energy) | **3** per turn. Cost of cards and Serve. |
| **Pressure** (Damage) | Reduces the opponent's Composure first, then Confidence. |

### 4.2 Player turn
Fixed order: **YOUR TURN** banner → player turn (no timer) → **RIVAL'S TURN** banner → rival drafting (animated) → loop until someone gives up. Timing and architecture details are in [GRAND_DESIGN.md §1](GRAND_DESIGN.md).

1. Composure → 0, Heat → 3, draw **5** cards.
2. Play cards (by **dragging**):
   - **Ingredient** → drag onto one of the **2 Stations**. Some have a small immediate effect.
   - **Technique** → drag up and out of the hand. Immediate effect (Pressure, Composure, draw) or modifies ingredients.
3. **Serve** (a button per Station, **1 Heat**, once per turn): everything on that Station is served. The Station is empty again.
4. Optional, free: **move the top card** to the other Station (once per turn) or **Clear** a Station (discard the whole stack, using the same move allowance).
5. End Turn (`E`): the hand is discarded. **Stations stay** into the next turn.

> Stations that persist between turns are the core decision: Serve now for a small result, or hold for a big recipe while absorbing the opponent's pressure? You can prepare two dishes at once.

### 4.3 Station Stack
- **2 Stations** per side (down from 3, decided 23 Nov after playtesting), maximum **6** cards per Station (**7** with *Bigger Plate*).
- Ingredients stack downward like solitaire. Older cards show only a name ribbon + tag icon, the newest card is fully visible (gold frame = can be taken). Only the top card can be dragged.
- An **Order Ticket** above each Station shows the **most likely recipe**, its ingredient order, and the next step (blinking). Off track → grey "???". Recipe complete → **PERFECT!** / **COOKED** stamp. The ticket may give hints, so the Recipe Book is not locked during duels.

### 4.4 Recipe matching (tags + order)
| Result | Condition | Effect |
|---|---|---|
| **Perfect** | Stack = the recipe's exact order, from the first card | Recipe effect **×1.5** |
| **Cooked** | All recipe ingredients present, different order | Recipe effect ×1.0 |
| **Garnish** | Extra ingredients after the recipe is complete | +1 Quality per ingredient (max +2) |
| **Improvised** | Matches no recipe | Pressure = 2 × number of ingredients |

| Tag | Example ingredients |
|---|---|
| `PROTEIN` | Egg, Chicken, Beef, Fish |
| `CARB` | Rice, Bread, Pasta |
| `VEGGIE` | Tomato, Onion, Mushroom |
| `FAT` | Butter, Olive Oil |
| `DAIRY` | Cheese, Milk, Cream |
| `SPICE` | Chili, Garlic, Pepper |
| `SAUCE` | Stock, Tomato Sauce, Soy Sauce |

- A recipe asks for a tag (`FAT`) or a **key ingredient** (`card:beef`) at each step. The full order of every recipe is in [ART_DIRECTION.md §6.4](ART_DIRECTION.md); the final source of truth is `godot/data/recipes/*.tres`.
- If more than one recipe matches, the UI shows the matching ones and the ones that are **one step short** in real time.

### 4.5 Quality & Hype
- Each ingredient has **Quality** 1–3. Upgrades and certain techniques raise it.
- **Recipe effect = (base value + total Quality on the Station) × Perfect multiplier.**
- **Hype Meter** (audience): every recipe has its own Hype value (Omelette 25, Sandwich 30, Burger 40, etc.), plus some from certain cards. When full (100), the **Signature Dish** unlocks.

### 4.6 Signature Dish — the anime moment
- A special MC card that appears in hand when Hype is full, once per duel. **Apis only**: the rival's Hype is just an audience meter.
- Effect: Serve a Station with **×2** effect, then a **cinematic cut-in**: chef close-up, aura, speed lines, a big SFX word, opponent and crowd reactions. ✅ effect, ⏳ cinematic cut-in.
- This is the "money shot" for GIFs, the trailer and the judges' impression.

### 4.7 Chef's Flow & Modifiers ✅
- Every **Perfect Order** Serve = +1 Flow. The player's threshold is **1 → 2 → 3** (then stays at 3); when reached, pick **1 of 3 modifiers**.
- Per duel: Flow and modifiers reset at the start of the next duel, and they stack. The rival also gets modifiers (higher thresholds for early rivals).
- 10 starting modifiers (Hot Pan, Steady Hands, Encore, Extra Burner, Prep Cook, Crowd Favorite, Spice Whisperer, Free Move, Mise Master, Plating Pro). List and offer rules: [GRAND_DESIGN.md §5](GRAND_DESIGN.md), [MODIFIERS.md](MODIFIERS.md).

| Meter | Rises from | Reward | Nature |
|---|---|---|---|
| Hype | Serving any recipe | Signature Dish | One-shot burst |
| Chef's Flow | Serving a Perfect Order | Modifier | Permanent within the duel, stacks |

### 4.8 Statuses (all have tooltips)
| Status | Effect |
|---|---|
| **Spicy** | Lose X Confidence at the start of the turn, then X−1. |
| **Flustered** | Pressure dealt −25%. |
| **Rattled** | Pressure received +50%. |
| **Burnt** | Next Serve has −50% effect. |
| **Focus** | +X Pressure on all attacks (permanent within the duel). |
| **Inspired** | Draw +1 next turn. |

### 4.9 Opponent: rival drafting ✅
Replaces the Intent system (the old §4.6). Always **1 vs 1**, and the rival plays by the same rules as the player.

- The rival has a **deck, Recipe Book, hand, Heat and 2 Stations**. `RivalAI` picks one action per step: place an ingredient, play a Technique, Serve, or End Turn. AI profiles: `greedy` (Tony), `trickster` (Rosa), `showman` (Marco), `patient` (Élodie), `boss` (Bruno).
- **Information:** the player sees card backs (the count) in the rival's hand and Stations, their Heat, damage, buffs/debuffs, and the dish served (name + PERFECT/COOKED) at Serve time. The contents of the rival's cards are hidden. The replacement for Intent is **mood** (Confident, Wary, Smug, Angry emotes).
- **Fairness promise:** the rival uses the same deck, shuffle and pity rules; does not see the player's hand or Station contents; its draws are not rigged.
- **RNG:** duel outputs are deterministic (damage, Quality, effects). Only inputs are random: shuffle, draw, offers. There is an anti-clump shuffle and **Mise en Place** (a guarantee that the hand has at least one ingredient, shown as "✨ Mise en place!"). Separate RNG streams per purpose so AI decisions never shift the player's draws ([GRAND_DESIGN.md §4](GRAND_DESIGN.md)).
- Hold click / Space during the rival's turn = ×3 speed.

### 4.10 Almanac ✅
A knowledge book in the HUD (book button or `Tab`, pauses the game). Tabs: Ingredients, Techniques, Recipes, Rivals, Keywords. Entries unlock when discovered (deck, reward/shop, or a rival serves it) and are saved across runs in `user://almanac.save`. This is **knowledge, not power**, so it does not break the no-meta-progression decision. The Recipes tab has a **combination finder**.

### 4.11 Cuisines, rival weaknesses & Reputation ⏳
*Decided 24 Nov 2026.* Gives builds something to counter and something that counters them. Every rival has a home cuisine they shrug off and one cuisine they have never learned. On top of that, the city remembers what *you* cook.

**Cuisines.** Every recipe has exactly one `cuisine`. Improvised dishes have none.

| Cuisine | Flavor | Home of |
|---|---|---|
| `HOME` | Family-kitchen basics. **Neutral:** never a weakness, specialty or reputation | Apis |
| `ASIAN` | Noodles, rice, soy, skewers | Tony |
| `MEXICAN` | Tortillas, chili, street food | Rosa |
| `ITALIAN` | Pasta, risotto, tomato | Marco |
| `FRENCH` | Eggs, butter, soups, technique | Élodie |
| `AMERICAN` | Grill, diner, BBQ | Bruno |

**Rival traits.** Each rival has a **Specialty** (their home cuisine) and a **Weakness** (a cuisine they cannot cook). The weaknesses form a loop, so each cuisine is exactly one rival's weakness and no single build counters everyone:

```
ASIAN → beats Rosa (MEXICAN) → beats Élodie (FRENCH) → beats Tony (ASIAN)
AMERICAN → beats Marco (ITALIAN) → beats Bruno (AMERICAN)
```

**When the player Serves a recipe** (Cooked or Perfect, including the Signature Dish):

| Case | Effect | Feedback |
|---|---|---|
| **Weakness hit** | **+6 Pressure** (flat, added after all multipliers). The rival is **Stumped**: −1 Heat on their next turn (does not stack). Hype **+10**. | Ticket chip `WEAK!` · popup *"THEY'VE NEVER TASTED THIS!"* · rival emote Shocked |
| **Specialty** | **−6 Pressure** (flat, after multipliers, min 0). Other effects (Composure, statuses, draw) still apply. | Ticket chip `HOME` · popup *"SEEN IT BEFORE."* · rival emote Smug |
| Neutral / `HOME` / Improvised | No change | — |

- The modifiers are **flat on purpose**: Perfect ×1.5 and Signature ×2 already multiply, and a third multiplier would end duels in one Serve. The flat values are `@export` tunables.
- The rival's own Serves are not affected. The player's counter-pressure comes from **Reputation** (below).
- The weakness is a bonus, never a requirement. Every rival must stay beatable without it (`tests/balance.gd`).

**Discovery (Almanac).** A rival's **Specialty is always public** (it is who they are: the taco truck queen cooks Mexican). The **Weakness starts as `???`**. It is hinted in the rival's pre-duel line (Rosa: *"Tacos, burritos, I've made it all... just not that fancy rice stuff."*) and **revealed** the first time the player hits it. After that it shows in the Almanac Rivals tab, on the rival's HUD badge, and on that rival's encounter card on the Course Path, so later runs can plan around it. This is knowledge, not power (it fits the no-meta-progression rule).

**Adaptive rivals.**
- **Élodie** *(Elite, `patient`)*: after the player hits her weakness **twice**, she has "studied it" and the weakness turns off for the rest of the duel (`STUDIED` chip).
- **"Iron" Bruno** *(Boss)*: in phase 2 his weakness **switches** from `ITALIAN` to `FRENCH`, with an announcer callout. The player needs a plan B.

**Reputation (the counter that points at the player).**
- `RunState` counts the player's Cooked/Perfect Serves per cuisine over the whole run (`HOME` is not counted).
- **Your Reputation** = the cuisine with the most Serves, if it has **≥ 4** and is strictly ahead of the rest. Otherwise you have no Reputation yet. It is shown on the run HUD/progress strip (*"Known for: ASIAN"*).
- **Elites and the Boss come prepared:** your Reputation counts as an **extra Specialty** for them (−6 Pressure, `KNOWN` chip, pre-duel line *"So you're the noodle kid. I've practiced."*). Regular duels do not use it, so early specialization still pays off.
- If your Reputation is that rival's Weakness, they **cancel out** (neutral): they prepared, but still can't really cook it.
- Result: going all-in on one cuisine is strong early, but a second book or a mixed deck matters for the Elite and the Boss.

**UI summary.** Cuisine icon on recipe cards, the Recipe Book and the Order Ticket. The ticket's predicted recipe shows `WEAK!` / `HOME` / `KNOWN` *before* you Serve, so the choice is always informed. Rival HUD badge: Specialty + Weakness icons. VS screen shows both.

**Implementation sketch.** `RecipeDef.cuisine` (enum) · `EnemyDef.specialty`, `weakness`, `weakness_phase2`, `studies_weakness_after` · the flat ±Pressure applies in `Duel`'s Serve resolution, which emits `cuisine_reaction(side, kind)` for the UI · `RunState` keeps the per-cuisine tally and passes Reputation into the duel · `Almanac` stores weakness discovery per rival · tunables (`weakness_bonus`, `specialty_penalty`, `reputation_threshold`, `stumped_heat`) are `@export` on the duel system node in `main.tscn`.

## 5. Run progression ⏳

### 5.1 Course Path
- Replaces the branching map. After each node, the player picks **1 of 2–3 encounter cards** (type icon + reward hint). Market Street has ±9 choices, then the Boss.
- **Generator rules:** no Elite in the first 3 nodes; at least 1 Shop and 1 Practice Kitchen; the node before the Boss is always a Practice Kitchen.
- Above it is a small progress strip: nodes passed, current position, and the boss at the end. "ROUND N" in the announcer = the Nth duel.

### 5.2 Rewards
| Source | Reward |
|---|---|
| Duel | Pick 1 of 3 cards + Tips |
| Elite | Card + **Kitchen Tool** (relic) + a chance at a Recipe Book |
| Shop | Cards, Kitchen Tools, **Recipe Books**, card removal |
| Boss | Win the run |

Reward offers use the `offers` RNG stream (reproducible from a single run seed).

### 5.3 Recipe Books
- Each book holds **2–3 themed recipes**. Buying a book means mastering all of its recipes.
- The player starts with the **Basics Cookbook**. Other books are bought in the Shop (75–150 Tips) or earned from Elites.

| Book | Build direction | Status |
|---|---|---|
| Basics Cookbook | All-rounder (starter) | ✅ |
| Grill Master's Notes | Big Pressure | ✅ |
| Spice Route Journal | Stack Spicy | ✅ |
| Comfort Food Diary | Sustain/Composure | ✅ |
| Pâtisserie Secrets | Long combos, Quality scaling | Stretch |
| Speed Kitchen Manual | 2-ingredient recipes, Serve every turn | Stretch |

Books stay grouped by **playstyle**, not cuisine. Each one mixes cuisines so every build has counters (§4.11, §6.3).

### 5.4 Practice Kitchen (rest site)
Pick one: **Rest** (restore 30% Confidence), **Upgrade** one card, or **Master a Recipe** (raises the recipe's base effect).

## 6. Jam-version content

### 6.1 Starter Deck (10) ✅
| Card | Type | Cost | Effect |
|---|---|---|---|
| Egg ×2 | `PROTEIN` | 0 | Q1 |
| Bread | `CARB` | 0 | Q1 |
| Tomato | `VEGGIE` | 0 | Q1 |
| Butter | `FAT` | 0 | Q1 |
| Quick Chop ×3 | Technique | 1 | 6 Pressure |
| Deep Breath ×2 | Technique | 1 | 5 Composure |

### 6.2 Reward pool (target ±33 cards total; **22 exist, 10 missing**)
| Card | Type | Cost | Effect | Status |
|---|---|---|---|---|
| Chicken | `PROTEIN` | 1 | Q2 | ✅ |
| Beef | `PROTEIN` | 1 | Q2, steak key ingredient | ✅ |
| Fish | `PROTEIN` | 1 | Q2, +3 Composure | ✅ |
| Rice | `CARB` | 0 | Q1, draw 1 | ✅ |
| Pasta | `CARB` | 1 | Q2 | ✅ |
| Onion | `VEGGIE` | 0 | Q1, opponent Flustered 1 | ✅ |
| Mushroom | `VEGGIE` | 1 | Q2 | ✅ |
| Chili | `SPICE` | 0 | Q1, opponent Spicy 2 | ✅ |
| Garlic | `SPICE` | 0 | Q1, +2 Composure | ✅ |
| Cheese | `DAIRY` | 1 | Q2 | ✅ |
| Cream | `DAIRY` | 1 | Q1, +1 Quality to other ingredients on the Station | ⏳ |
| Stock | `SAUCE` | 0 | Q1 | ✅ |
| Tomato Sauce | `SAUCE` | 1 | Q2 | ✅ |
| Olive Oil | `FAT` | 0 | Q1, +1 Heat next turn | ⏳ |
| Sauté | Technique | 1 | +1 Quality to all ingredients on the Station | ⏳ |
| Flambé | Technique | 2 | 12 Pressure, Hype +10 | ✅ |
| Mise en Place | Technique | 0 | Draw 2 | ✅ |
| Taste Test | Technique | 1 | Look at the top 3 cards, take 1 Ingredient | ⏳ |
| Stare Down | Technique | 1 | Opponent Rattled 2 | ✅ |
| Plating Art | Technique | 1 | Next Serve has Hype ×2 | ⏳ |
| Second Helping | Technique | 2 | Return 1 ingredient from the last Serve to hand | ⏳ |
| Clean Station | Technique | 0 | Discard 1 ingredient from the Station, draw 1 | ⏳ |
| Crowd Pleaser | Technique | 1 | Hype +20 | ✅ |
| Soy Sauce | `SAUCE` | 0 | Q1, Fried Rice key ingredient (§4.11) | ⏳ |
| Noodles | `CARB` | 1 | Q2, Ramen key ingredient (§4.11) | ⏳ |
| Tortilla | `CARB` | 0 | Q1, Tacos/Quesadilla key ingredient (§4.11) | ⏳ |

(Egg, Bread, Tomato, Butter, Quick Chop and Deep Breath from the starter deck are also ✅.)

### 6.3 Recipes ✅ (13 in `godot/data/recipes`, +4 ⏳ planned for cuisines)
| Recipe | Book | Cuisine (§4.11) | Needs (tag/key ingredient) | Base effect |
|---|---|---|---|---|
| **Omelette** | Basics | `FRENCH` | `FAT` → *Egg* → `VEGGIE` | 10 Pressure, 5 Composure |
| **Toast** | Basics | `HOME` | `CARB` → `FAT` | 6 Pressure, draw 1 |
| **Fresh Salad** | Basics | `HOME` | `VEGGIE` → `VEGGIE` | 8 Composure, remove 1 debuff |
| **Sandwich** *(new)* | Basics | `HOME` | *Bread* → `PROTEIN` → `VEGGIE` → *Bread* | 12 Pressure, 6 Composure |
| **Fried Rice** ⏳ | Basics | `ASIAN` | *Rice* → *Egg* → *Soy Sauce* | 8 Pressure, draw 1 |
| **Classic Steak** | Grill Master | `AMERICAN` | `FAT` → *Beef* → `SPICE` | 20 Pressure |
| **Skewers** | Grill Master | `ASIAN` | `PROTEIN` → `SPICE` | 8 Pressure, Focus 1 |
| **Mixed Grill** | Grill Master | `AMERICAN` | `FAT` → `PROTEIN` → `PROTEIN` | 16 Pressure, opponent Rattled 1 |
| **Burger** *(new)* | Grill Master | `AMERICAN` | *Bread* → *Beef* → *Cheese* → `VEGGIE` → *Bread* | 22 Pressure, 6 Composure |
| **Arrabbiata** | Spice Route | `ITALIAN` | `SPICE` → `SAUCE` → `CARB` | 8 Pressure, Spicy 4 |
| **Hot Wings** | Spice Route | `AMERICAN` | *Chicken* → `SPICE` → `SPICE` | 6 Pressure, Spicy 6 |
| **Tacos** ⏳ | Spice Route | `MEXICAN` | *Tortilla* → `PROTEIN` → `VEGGIE` → `SPICE` | 10 Pressure, Spicy 2 |
| **Warm Soup** | Comfort Food | `FRENCH` | `VEGGIE` → `PROTEIN` → `SAUCE` | Restore 5 Confidence, 8 Composure |
| **Mac & Cheese** | Comfort Food | `AMERICAN` | *Pasta* → `FAT` → `DAIRY` | 8 Pressure, 8 Composure |
| **Mushroom Risotto** | Comfort Food | `ITALIAN` | *Rice* → *Mushroom* → `DAIRY` | 10 Composure, Inspired |
| **Ramen** ⏳ | Comfort Food | `ASIAN` | *Noodles* → `SAUCE` → *Egg* | Restore 4 Confidence, 6 Pressure, 6 Composure |
| **Quesadilla** ⏳ | Comfort Food | `MEXICAN` | *Tortilla* → *Cheese* → *Tortilla* | 6 Pressure, 8 Composure |

**Cuisine coverage rule:** every book has at least 2 non-`HOME` cuisines, so no build is shut out against any rival. Basics: French, Asian · Grill Master: American, Asian · Spice Route: Italian, American, Mexican · Comfort Food: French, American, Italian, Asian, Mexican. Effects marked ⏳ are first guesses for `tests/balance.gd`.

*All effects add the total Quality on the Station, then multiply by the Perfect multiplier (×1.5).*

### 6.4 Kitchen Tools (±8) ⏳
Run rewards (unlike the Flow modifiers, which are per duel). They need to be matched to the Station Stack.
- **Grandma's Pan**: the first recipe Served each duel gets +5 Pressure.
- **Sharp Santoku**: Techniques that deal Pressure get +2.
- **Bigger Plate**: a Station holds 7 cards (up from 6).
- **Lucky Apron**: start each duel with 25 Hype.
- **Spice Rack**: each `SPICE` played gives +1 Composure.
- **Butter Dish**: `FAT` ingredients get +1 Quality.
- **Cast-Iron Lid**: a Station held into the next turn gives +3 Composure.
- **Food Critic's Pen**: Signature Dish +50%.

### 6.5 Opponents (Market Street)
Confidence scales to a player at 100 (phase G, 23 Nov). ✅ values were tuned with `tests/balance.gd`.

| Opponent | Type | Confidence | AI profile | Specialty | Weakness | Gimmick | Status |
|---|---|---|---|---|---|---|---|
| **Tony**, street noodle cook | Duel | **45** | `greedy`, Heat 2, hand 4 | `ASIAN` | `FRENCH` | Serves as soon as a recipe is available. Tutorial opponent. | ✅ data + 3D model + animations |
| **Rosa**, taco truck queen | Duel | **50** | `trickster`, Heat 3, hand 4 | `MEXICAN` | `ASIAN` | Onion/Stare Down deck, often applies Flustered/Rattled. | ✅ data, ⏳ 3D model |
| **Marco**, pizza showman | Duel | ±42 *(not tuned yet)* | `showman` | `ITALIAN` | `AMERICAN` | Holds a stack for 2 turns for a big dish; the Confident mood shows a turn earlier. Teaches the importance of Composure. | ⏳ |
| **Élodie**, rival pâtissière | Elite | ±60 *(old scale)* | `patient` | `FRENCH` + your Reputation | `MEXICAN` (*studied* after 2 hits) | If a player Station holds ≥ 5 cards at the start of the rival's turn, the player is Rattled 1 (reads the card *count*, which is public). | ⏳ |
| **"Iron" Bruno**, butcher-turned-grill master | Boss | ±110 *(old scale)*, 2 phases | `boss` | `AMERICAN` + your Reputation | `ITALIAN` → `FRENCH` in phase 2 | Phase 1: Burnt every 2 turns. Phase 2 (≤50%): Heat +1 and Focus +1 each turn. | ⏳ |

Specialty/Weakness rules are in §4.11. Rival decks should lean on their Specialty cuisine so their dishes match who they are.

Balancing results (300 duels, starter deck): Tony loses ±80% of the time to a simple player (98% to the smart bot), Rosa 38% / 87%, duels last ±4.7–7.5 turns, the rival takes ±4.2–4.8 actions per turn. Details: [GRAND_DESIGN.md §8.2](GRAND_DESIGN.md). Marco, Élodie and Bruno need re-tuning for the 100-Confidence scale.

### 6.6 Events (3) ⏳
Short text choices with a portrait. Examples: a mysterious ingredient merchant, a food critic asking for a taste, helping an overwhelmed vendor.

## 7. Visuals & presentation
The full visual direction, 24-color palette, pixel pipeline, HUD, emotes, announcer and asset list are in [ART_DIRECTION.md](ART_DIRECTION.md). In short:

- **Warm pixel diorama:** the low-poly 3D world is rendered at 640×360 (SubViewport, nearest) then scaled ×3. The pixel filter is **on by default** (`P` toggles it). "Market Street" palette: wood, cream, red/orange accents.
- **Fixed, high-angle diorama camera.** Two cooking tables facing each other, the rival on the right, the audience as silhouette blocks.
- **The table is the stage.** The HUD feels physical (wooden boards, paper, ribbons), with diamond badges for portraits and a segmented gauge for Hype.
- **Faces that talk.** The rival reacts through emotes (Smug, Shocked, Angry, Sad, Confident, Wary).
- **Every moment has a stamp.** Announcer: 3·2·1 → ROUND N → FIGHT! → FINISHED → **YOU WINS!** / **LOSER**.

**UX principles:** every choice is a card (encounter, reward, tool, recipe book); state reads at a glance (done = checkmark, current = bright with a frame, locked = dark + padlock); reveals are moments (overlay, animation, sound); keyword tooltips everywhere.

| Screen | Status |
|---|---|
| Duel (HUD v2, Card v2, Recipe Book v2, Station Stack, Almanac) | ✅ |
| Course Path | ⏳ large encounter cards, progress strip |
| Reward / Recipe Book reveal | ⏳ dark overlay, card reveal, "Click anywhere to continue" |
| Pick a card / Kitchen Tool | ⏳ 3 choices, thick frames, keyword tooltips |
| Tutorial | ⏳ paged modal, shown contextually the first time a feature appears, can be reopened |
| Deck & recipe viewer | ⏳ read-only (the Almanac already covers part of it) |

### 7.1 Assets (fal track)
- **3D:** the Market Street stage, the MC, 5 chefs, and ±13 dish models that appear on Serve. Characters: GLBs with a Mixamo rig. ✅ **Apis** and **Tony** (idle, chop, busy, victory, lose animations). ⏳ Rosa, Marco, Élodie, Bruno, the stage, the dishes. Made through image-to-3D on **fal** from concept art, then cleaned up, or modeled as simple low-poly if the result falls short.
- **2D:** card illustrations, modifier icons and dialogue portraits from **fal** / Nano Banana, with a fixed style reference for consistency. The prompt sheets are already in the repo. White SVG icons for tags and statuses ✅.
- **Minimum animations per chef:** idle, chop, busy, victory, lose. If rigging is too expensive, use procedural animation.
- **Required moments:** Signature Dish cut-in (3D close-up render + 2D speed-line overlay), the opponent's reaction when Confidence hits zero, a VS screen before Bruno.

## 8. Audio (ElevenLabs track)
- ✅ `Audio` autoload: looping music and basic SFX are already wired in.
- ⏳ **Short voice lines** for each chef (taunt, hit by a big Serve, giving up), the MC (Signature Dish shout), and the cooking-show announcer ("SERVE!", "INCREDIBLE!").
- **SFX:** pan sizzle, chopping, plates, crowd cheers, cut-in whoosh. Music: an upbeat duel theme and a boss theme.
- All audio is generated during development and stored as files in the build. **No API keys in the game.**

## 9. Technical architecture (Godot 4.7)

```
godot/
  project.godot, export_presets.cfg (Web preset → build/web/index.html)
  data/        Resource .tres, 1 file per item: cards, recipes, enemies, books, decks, modifiers
  scripts/
    data/      Resource classes: CardDef, RecipeDef, EffectDef, EnemyDef, AiProfile, BookDef, DeckDef, ModifierDef, StatusDefs
    core/      pure logic, no nodes: Duel, Kitchen, RecipeMatch, RivalAI, SeededRng, Almanac, CardInstance
    stage/     chef, stage (3D stage)
    ui/        duel_ui, card_view, hud, turn_director, announcer, emote_bubble, almanac_view, keywords
    audio/     Audio autoload
  scenes/      main.tscn (system nodes), stage/, ui/duel_ui.tscn (HUD, unique-name nodes)
  tests/       sim.gd, balance.gd, audio_check.gd, glb_check.gd, ui_drive.gd, chef_drive.gd, hit_probe.gd
```

- **Data-driven:** adding content = adding a `.tres` file, not writing new logic.
- **Logic separated from visuals:** `scripts/core/` uses no nodes. Visuals listen to `Duel` signals (`card_played(side, …)`, `dish_served(side, …)`, `flow_offer`, etc.), so duels can be simulated headless (`tests/sim.gd`, `tests/balance.gd`).
- **Systems are nodes in scenes,** not spawned from code. Tunable values use `@export` so they show in the Inspector.
- **One run save** in `user://` (⏳). The Almanac already has its own save.

**Jam requirements checklist**
- [ ] Static Web build, `index.html` at the root (Web preset exists, not yet tested in a browser)
- [ ] First frame < 10 seconds, initial download < 50 MB, 45+ fps at 1080p
- [ ] Responsive at 1920×1080, 1366×768, 2560×1440, 3440×1440, 1024×640 (`tests/hit_probe.gd` already exists)
- [ ] No login, ads, tracking or API keys in the build
- [ ] `og:ready` signal via the OpenGame SDK
- [ ] Credits and a check of the fal & ElevenLabs terms
- [ ] Fully playable with a mouse
- [x] Git from day one (proof of development history)

## 10. Schedule

| Week | Dates | Focus | Milestone | Status |
|---|---|---|---|---|
| 1 | 22–28 Nov | Core combat, Station Stack, rival AI, RNG, Flow, Almanac, basic audio, HUD, 2 chefs | **A full duel is playable** | ✅ reached early (23 Nov) |
| 2 | 29 Nov–5 Dec | RunState, Course Path, rewards, Shop + Recipe Books, Practice Kitchen, Kitchen Tools, events, save, Marco/Élodie/Bruno, the remaining cards, cuisines + rival weaknesses + Reputation (§4.11) | **One full graybox run** | ⏳ |
| 3 | 6–12 Dec | Assets (stage, chefs, dishes, cards), final UI, cut-in, VS screen, ElevenLabs voices, run balancing | **Market Street vertical slice** | ⏳ |
| 4 | 13–18 Dec | Tutorial, juice, test 5 window sizes, Web export, **first upload 14 Dec**, fixes from review. Final no later than 17 Dec | **Submit** | ⏳ |

**If the schedule slips, cut in this order:** events → Reputation (keep weaknesses) → Marco → Kitchen Tools 8 → 5 → rigged animation (replace with procedural) → Bruno phase 2.

## 11. Changes from earlier versions

| Feature | Decision | Reason |
|---|---|---|
| Vite + TypeScript + Three.js | **Replaced: Godot 4.7** (22 Nov) | The 3D pixel pipeline, animation and audio are easier. The old version stays in `src/` as reference |
| 5-slot Plate | **Replaced: Station Stack** | Ordered recipes, two dishes can be prepared at once, reads like solitaire |
| 3 Stations | **Replaced: 2 Stations** (23 Nov) | More room on screen and duels are easier to read |
| Opponent Intent | **Replaced: rival drafting** | The opponent plays by the same rules, which is fairer and livelier |
| "No recipe hints" | **Changed:** the Order Ticket may give hints | New players need to know the right order |
| 3 districts (Gourmet Avenue, Grand Arena) | **Stretch:** Gourmet Avenue + Madame Céleste if run 1 is finished in week 3 | 4-week scope |
| Meta-progression (Chef Rank, Kitchen Prep, Challenges) | ✂️ **Cut** | Judges play 1–2 runs. Exception: Almanac discovery (knowledge, not power) |
| Secret Seasoning (consumable) | ✂️ **Cut** | An extra system with little value for a jam |
| Resolution/fullscreen settings | **Replaced:** volume only | The game runs in a browser |
| Windows build / itch.io | **Replaced:** web-only OpenGame | Jam rules |
| "No voice acting" | **Changed:** short voice lines via ElevenLabs | Sponsor track |

## 12. Open questions
- [x] ~~Title~~ → **Finale** (working title).
- [x] ~~MC name~~ → **Apis Tetrarch** (Apis), placeholder.
- [x] ~~Pixel filter~~ → **used**, on by default.
- [x] ~~Number of Stations~~ → **2**.
- [x] ~~Do builds need a counter?~~ → **Cuisines, rival weaknesses & Reputation** (§4.11, 24 Nov).
- [ ] **Judges as a per-duel modifier** (e.g. a judge who likes spice: `SPICE` recipes +30%)? Stretch candidate. If added, build it on the §4.11 cuisine tags (e.g. "today's crowd craves `MEXICAN`").
- [ ] **Weakness/Specialty values (±6 flat)**: check in `tests/balance.gd` that every rival stays beatable without its weakness and that a weakness hit feels big but doesn't end the duel.
- [ ] **Is telegraphing enough without Intent?** Mood + the card count on the rival's stations must be enough for defensive decisions. Check in the first playtest; if not, add a "ready glow" on rival stations that can be Served.
- [ ] **Élodie's and Bruno's Confidence scale** for a 100-Confidence player: tune with `tests/balance.gd` when they are built.
