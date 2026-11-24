# Grand Design — Turn Sequence, Rival AI, RNG, Chef's Flow, Almanac

> Written 22 Nov 2026 from the *gameplay-mechanics-phase-timing* session discussion. This document **replaces GDD §4.6 (opponent Intent)** and adds new systems on top of the Station Stack ([ART_DIRECTION.md §6](ART_DIRECTION.md#6-station-stack--ordered-recipes-grand-design-proposal)).
> Referenced code: Godot 4 in `godot/` (`scripts/core/duel.gd`, `scripts/ui/duel_ui.gd`, `scripts/data/enemy_def.gd`).

## 0. Decisions (22 Nov)

| # | Topic | Decision |
|---|---|---|
| 1 | Turn pacing | Fixed order: **YOUR TURN banner → player turn → RIVAL TURN banner → rival drafting (animated) → loop**, until someone wins or loses. |
| 2 | Logic vs pacing | `Duel` stays pure logic. Pacing is handled by a **Turn Director** in the UI layer. |
| 3 | Rival | The rival **drafts by the same rules** as the player: deck, hand, Heat, 2 stations, Serve. No more Intent patterns. |
| 4 | Information | Rival cards are **blind**. The player sees **card backs** (the count) on the rival's stations, animations, damage, buffs/debuffs and stats. |
| 5 | Intent | Removed. Replaced by the rival's **mood** (vague emotes). |
| 6 | Almanac | A **discovered** model, openable during a duel (the game pauses). Recipes the rival serves are recorded too. |
| 7 | Fast-forward | Hold click/Space = rival turn ×3. |
| 8 | AI level | Early rivals are greedy → Elite is patient → Boss has gimmicks. |
| 9 | RNG | **Deterministic** outputs. Random inputs use light pseudo-randomness (anti-clump + Mise en Place). The AI uses the same RNG rules. |
| 10 | Power-ups | **Chef's Flow**: Perfect Order → pick 1 of 3 modifiers, threshold rises 1 → 2 → 3 (phase G; originally 2 → 3 → 4), **per duel**, stackable. |
| 11 | Rival & modifiers | The rival can also get modifiers (higher threshold for early rivals), shown as buff icons. |
| 12 | Marked pity | Bad-luck protection is **visible**: "✨ Mise en place!". |

---

## 1. Turn Sequence — ✅ done 22 Nov (phase A)

### 1.1 Order

```
┌──────────────┐   ┌────────────────┐   ┌────────────────┐   ┌──────────────────────┐
│ YOUR TURN    │ → │ Player turn    │ → │ TONY'S TURN    │ → │ Rival drafting       │
│ banner       │   │ (free, no time │   │ banner         │   │ (one action at a     │
│              │   │  limit)        │   │                │   │  time, face-down)    │
└──────────────┘   └────────────────┘   └────────────────┘   └──────────────────────┘
        ↑                                                               │
        └───────────────────── loop until win / lose ───────────────────┘
```

A win/loss can cut the sequence at any point (Spicy tick, Serve, etc.). The Director jumps straight to the result sequence (ART_DIRECTION §7).

### 1.2 Timing (normal speed)

| Step | Content | Duration |
|---|---|---|
| **P1** Banner | "YOUR TURN" slam + *Turn change* SFX | 1.0 s |
| **P2** Turn start | Composure → 0, Spicy tick (floating number), then draw (cards fly in one by one, 0.08 s/card) | 0.5–1.0 s |
| **P3** Player turn | Input open. No timer. | free |
| **P4** End Turn | Hand is discarded (animation to the discard pile) | 0.4 s |
| **E1** Banner | "TONY'S TURN" (rival color) | 1.0 s |
| **E2** Rival turn start | Composure → 0, Spicy tick, card backs fly to the rival's hand | 0.5 s |
| **E3** Rival actions (loop) | *Think* (a "…" bubble, 0.35 s) → action (see 1.3) | 0.6–1.8 s/action |
| **E4** Rival turn end | Rival's hand is discarded, a pause | 0.4 s |

Target rival turn length: **4–7 seconds** with 3–6 actions. Longer feels slow to the judges.

### 1.3 Rival action animations

| Action | What is seen | Duration |
|---|---|---|
| Place an ingredient | A card back slides to the rival's station, the stack grows | 0.5 s |
| Technique | The card flips briefly **only for its effect** (effect icon, not the card name), then a number/status floats up | 0.7 s |
| Move the top card | A card back shifts between stations | 0.4 s |
| Clear a station | The stack is swept to the discard pile | 0.4 s |
| **Serve** | The rival's station lights up → **dish reveal** (dish name + icon, PERFECT/COOKED) → damage to the player | 1.8 s |

> On Serve the dish is **revealed** (information after the action, just like the player sees damage). The individual ingredients are still not shown one by one, but the recipe is recorded in the Almanac (§5).

### 1.4 Fast-forward
- **Hold left click or Space** during the rival phase = all tweens ×3, *think* is skipped.
- Banners still appear (shortened to 0.4 s) so the player does not lose orientation.
- A "Rival speed: Normal / Fast" toggle in the volume menu (optional, if there is time).

### 1.5 Architecture

**`Duel` (logic)** gets an `"enemy"` phase and a step-by-step API:

```gdscript
duel.end_turn()               # P4: discard the hand, phase = "enemy". No longer calls the rival's turn.
duel.begin_enemy_turn()       # E2: rival Composure → 0, Spicy tick, queue this turn's actions.
duel.enemy_step() -> Dictionary
    # Applies ONE action, emits signals, then returns { kind, … }.
    # Phase A (Intent pattern): "attack" | "block" | "status" | "end". Phase C (AI): "place" | "technique" | "move" | "clear" | "serve" | "end".
    # "end" = E4 (end-of-rival-turn decay). enemy_actions_left() = remaining actions.
duel.start_player_turn()      # P2: phase = "player", Composure, Spicy, draw.
duel.run_enemy_turn()         # synchronous loop for tests/sim.gd (no animation).
```

**`TurnDirector` (UI, `scripts/ui/turn_director.gd`)** owns the sequence in 1.1:

```gdscript
func _rival_turn() -> void:
    _lock_input()
    await _banner(rival_name + "'S TURN")
    while duel.phase == "enemy":
        await _think()                      # "…" bubble (skipped during fast-forward)
        var a := duel.enemy_step()
        await _play_action(a)               # tween per the table in 1.3
        if a.kind == "end": break
    if duel.phase == "enemy":
        duel.finish_enemy_turn()
        await _banner("YOUR TURN")
        await _deal_hand()
    _unlock_input()
```

- All tweens go through one global `speed` (1.0 normal, 3.0 fast-forward).
- The existing `_busy` in `duel_ui.gd` is used as the input lock.
- The duel intro (3·2·1 FIGHT) that currently exists now flows straight into the "YOUR TURN" banner.

---

## 2. Symmetric Kitchen (core refactor) — ✅ done 22 Nov (phase B)

`Duel` currently keeps the hand, draw pile, stations, Hype and Heat **for the player only**. A drafting rival needs all of that too. Refactor:

```gdscript
class Kitchen:              # one per side: duel.kitchen["player"], duel.kitchen["enemy"]
    var fighter: Fighter    # Confidence, Composure, Heat, statuses (already exist)
    var draw_pile / hand / discard / exhausted
    var stations            # 3 × Array[CardInstance]
    var recipes             # from that side's Recipe Book
    var hype, flow, flow_threshold_index
    var modifiers: Array[ModifierDef]
    var served_this_turn, moved_this_turn
    var rng_shuffle: SeededRng
```

- `play / serve / move_top / clear_station / can_*` take a `side` (default `"player"` so the old UI keeps working).
- `_apply_effects`, `_do_serve`, statuses, Signature: all `side`-based, so the rival's rules = the player's rules.
- Signals carry a `side` argument: `card_played(side, card)`, `dish_served(side, …)`, etc.
- `Fighter.heat` already exists ("Player only"), now used by both.

---

## 3. Rival AI — ✅ core done 22 Nov (phase C), see §3.7

### 3.1 Data (new `EnemyDef`)

| Field | Content | Tony example |
|---|---|---|
| `deck` | The rival's `DeckDef` | 10 simple cards |
| `books` | Mastered Recipe Books | Basics |
| `max_heat` | Heat per turn | **2** |
| `hand_size` | Draw per turn | **4** |
| `profile` | `AiProfile` (3.3) | `greedy` |
| `flow_thresholds` | Chef's Flow thresholds | `[3, 4, 5]` |
| `gimmicks` | List of special rules (3.5) | — |

`pattern: Array[IntentDef]` is removed once the AI works. `IntentDef` is kept temporarily only as a fallback during the refactor.

### 3.2 How it thinks (one action per `enemy_step`)

1. Gather the **legal candidate actions**: place each ingredient on each station, play a Technique, move a card, clear, Serve each station, End Turn.
2. **Score** each candidate using a **preview** of the same logic the player uses (`RecipeMatch`, `preview_serve(side, station)` without applying effects).
3. Take the highest score. Ties → use `rng_ai` (a separate stream, §4.3).
4. If the best score is < the profile's `end_threshold`, or Heat is spent → `End Turn`.

**Scoring formula (outline):**

| Candidate | Score |
|---|---|
| Serve station s | `pressure_preview × w_attack + composure_preview × w_defend`; **+1000 if lethal**; −`w_patience` × the value of a bigger recipe that is 1 step away on that station |
| Place an ingredient | Progress toward the best recipe that station can reach; bonus if the order is still Perfect; penalty for breaking a nearly finished recipe |
| Pressure Technique | `pressure × w_attack` (+ lethal bonus) |
| Composure Technique | `composure × w_defend × danger` |
| Debuff | fixed value × `w_debuff` |

`danger` = an estimate of the player's threat from **public information only**: the number of cards on the player's stations, the player's Hype, and the rival's own Confidence. **The AI does not read station or hand contents.** The information is symmetric with the player's.

### 3.3 Profiles

| Profile | Behavior | `w_attack` | `w_defend` | `w_patience` | Used by |
|---|---|---|---|---|---|
| `greedy` | Serves as soon as a recipe matches, rarely defends | 1.0 | 0.3 | 0 | Tony |
| `trickster` | Likes debuffs, medium Serves | 0.8 | 0.5 | 0.2 | Rosa |
| `showman` | Holds a stack for a big dish, Perfect | 1.0 | 0.6 | 0.8 | Marco |
| `patient` | Perfect Order, defends when Confidence < 40% | 0.9 | 0.9 | 0.6 | Élodie (Elite) |
| `boss` | `patient` + phase gimmicks | 1.1 | 0.8 | 0.5 | Bruno |

### 3.4 Mood (replaces Intent)

The existing emotes (ART_DIRECTION §5) are triggered by the **AI's intent at the start of the turn**, not by the card contents:

| Mood | Trigger (from the AI's planning) | Emote |
|---|---|---|
| Confident | A station can be Served for ≥ 12 Pressure this turn | Wink `> ●` |
| Wary | The AI chooses to defend (high `danger`) | Narrowed eyes, sweat |
| Smug | Player Confidence ≤ 30% | already exists |
| Angry | Rival Confidence ≤ 25% | already exists |

The mood is vague: the player knows "a big attack is coming" but not how much or from which ingredients.

### 3.5 Visibility table

| Information | Does the player see it? |
|---|---|
| Number of cards in the rival's hand | ✅ (card backs) |
| Number of cards per rival station | ✅ (stack of card backs) |
| Contents of rival hand/station cards | ❌ |
| Rival Heat (pips) | ✅ |
| Rival Technique effect (icon + number) | ✅ when played |
| Rival dish name + PERFECT/COOKED | ✅ on Serve |
| Damage, Composure, buffs, debuffs, Hype, Chef's Flow, rival modifiers | ✅ |
| Rival mood | ✅ |
| Recipes the rival has mastered | ❌ until served (then recorded in the Almanac) |

### 3.6 Old gimmicks, translated

| Rival | Old GDD | Drafting version |
|---|---|---|
| Tony | Simple pattern | `greedy`, Heat 2, hand 4. Tutorial opponent. |
| Rosa | Often Taunts | Deck full of Onion/Stare Down, `trickster`. |
| Marco | 2-turn Cooking | `showman`: holds a stack for 2 turns for Mixed Grill/Classic Steak. The Confident mood appears one turn earlier. |
| Élodie | Full Plate → Rattled | Gimmick: if any player station holds ≥ 5 cards at the start of the rival's turn, the player is Rattled 1. |
| Bruno | Burnt every 2 turns, Phase 2 Focus | Gimmick: Burnt every 2 turns. Phase 2 (≤ 50%): Heat +1 and Focus +1 per turn. |

### 3.7 Implementation status (phase C, 22 Nov)

- ✅ `AiProfile` (Inspector) + `EnemyDef.deck / books / max_heat / hand_size / ai`. A rival without a deck/AI still uses the old Intent pattern.
- ✅ `RivalAI` (`scripts/core/rival_ai.gd`): place ingredients, Techniques, Serve; "paths that can be finished with this hand" lookahead; takes lethal; saves Heat for Serve; can play either side (used by the smart bot in `tests/sim.gd`).
- ✅ HUD: face-down rival stations + Hand + Heat above the rival's table (`%RivalKitchen` in `duel_ui.tscn`, anchor `RivalStationsAnchor` in `stage.tscn`), rival dish banner on Serve, Confident/Wary mood.
- ✅ Signature Dish only for Apis (GDD §4.5); rival Hype is just an audience meter.
- ✅ Data: Tony (`greedy`, Heat 2, hand 4, Basics), Rosa (`trickster`, Heat 3, hand 4, Basics + Spice).
- Initial balancing (smart bot, starter deck): Tony 98% win, ±2.8 turns, ±44/60 Confidence left. Rosa 85% win, ±3.5 turns, ±36/60 left.
- ⏳ Not yet: the AI moving/clearing stations, Élodie/Bruno gimmicks (those rivals are not in the data yet), `showman`/`patient`/`boss` profiles. RNG tie-break: ✅ phase D (§4.5).

---

## 4. RNG — ✅ core done 22 Nov (phase D), see §4.5

### 4.1 Map

| | Random input (before an action) | Random output (after an action) |
|---|---|---|
| Duel | Shuffle, draw, AI tie-break | **None.** Damage, Quality, recipe effects, modifiers: all certain. |
| Run | Modifier offers, card rewards, Course Path | None |

Principle: **what happens after the player acts can always be computed from the ticket and tooltips.** RNG only decides "which cards you get", never "whether it works".

### 4.2 Pseudo-random (light)

| Rule | Content | Applies to |
|---|---|---|
| **Anti-clump shuffle** | After Fisher–Yates, if 4+ Techniques are in a row among the top 5 cards, reshuffle (max 3 times, then accept it as is) | Player + rival |
| **Mise en Place** (bad-luck protection) | After the turn-start draw, if the hand **contains no ingredient that can be placed**, 1 Technique is swapped with the top ingredient of the draw pile. Max 1× per turn. Shown as "✨ Mise en place!" | Player + rival |
| **Rarity pity** (modifier offers) | 3 offers in a row without a Rare → the next offer is guaranteed to contain 1 Rare | Player |

No other pity. Shaping the odds is deckbuilding's job (removing cards, choosing ingredients, choosing books).

### 4.3 Separate streams

One run seed → derived into independent streams:

```
run_seed ─┬─ shuffle_player
          ├─ shuffle_enemy
          ├─ ai_tiebreak
          └─ offers (modifiers, rewards)
```

AI decisions do not shift the cards the player will draw. A run can still be reproduced from a single seed (debug, sim, a daily seed later).

### 4.4 Fairness promise (also written in the tutorial/credits)
- The rival uses the same deck, shuffle and pity rules.
- The rival does not see the player's hand or station contents.
- The rival's draws are not rigged based on the player's state.

### 4.5 Implementation status (phase D)
- ✅ `SeededRng.stream(seed, name)`: named streams from one `Duel.duel_seed` (FNV-1a of the name as a salt). Player/rival shuffles stay `seed` / `seed ^ ENEMY_RNG_SALT`; AI tie-breaks `ai_player` / `ai_enemy` in `Kitchen.ai_rng`. The `offers` stream is ready for phase E.
- ✅ Anti-clump (`Duel._shuffle`): 4+ Techniques among the top 5 cards → reshuffle, max 3×. Applies to the initial shuffle and discard reshuffles. Technique-heavy decks: opening clumps dropped from 95/400 to 2/400.
- ✅ Mise en Place (`Duel._mise_en_place`): after the turn-start draw, a hand with no placeable ingredient → 1 Technique swapped with the top ingredient of the draw pile (the Technique goes into that position, card count unchanged). Max 1× per turn, player + rival, `mise_en_place` signal. HUD: "Mise en place!" floats above the station (rival: above its face-down station; the card stays secret).
- ✅ AI tie-break (`RivalAI._consider`): scores within 0.05 count as a tie, picked uniformly from `ai_rng`. The rival no longer always fills station 1 first; a test makes sure this stream does not shift Apis's draws.
- Constants in `duel.gd` (`CLUMP_*`), not `@export`: these are core rules (pure logic), not per-scene tuning.
- ⏳ Modifier-offer rarity pity → phase E.

---

## 5. Chef's Flow & Modifiers — ✅ core done 22 Nov (phase E), see §5.5

### 5.1 Rules
- Every **Perfect Order** Serve = +1 Flow. Cooked/Improvised Serve = +0.
- Thresholds: **1 → 2 → 3** (then stays at 3). Lowered from 2 → 3 → 4 in phase G (§8.2). When reached, Flow returns to 0 and a **pick 1 of 3 modifiers** appears.
- **Per duel**: modifiers and Flow reset at the start of the next duel. Kitchen Tools remain a run reward (GDD §6.4).
- Player: a card-pick overlay (ref Image 3) appears **after the Serve finishes resolving**. The game pauses.
- Rival: picks automatically according to its profile. Announcer chip **"TONY GOT HOT PAN!"** (1 s) + an icon in the rival's modifier row.

| Meter | Rises from | Reward | Nature |
|---|---|---|---|
| Hype | Serving any recipe | Signature Dish | One-shot burst |
| **Chef's Flow** | Serving a **Perfect Order** | Modifier | Permanent within the duel, stacks |

### 5.2 Offer rules
1. No non-stackable modifier that is already owned.
2. At least 1 of the 3 **matches the build** (dominant tag in the deck or a mastered book).
3. Rarity pity (4.2).
4. Composition: 2 Common + 1 slot (Common 75% / Rare 25%).

### 5.3 Starting pool (±10)

| Modifier | Rarity | Effect | Stack |
|---|---|---|---|
| Hot Pan | Common | The first Serve each turn +3 Pressure | +3 per stack |
| Steady Hands | Common | +1 Composure each time you place an ingredient | +1 |
| Encore | Common | Perfect Order multiplier ×1.5 → +0.25 | +0.25 |
| Extra Burner | Common | +1 Heat on the turn after a Perfect Serve | ✗ |
| Prep Cook | Common | Draw +1 at the start of the turn | ✗ |
| Crowd Favorite | Common | Hype +10 each Serve | +10 |
| Spice Whisperer | Common | `SPICE` ingredients give the opponent Spicy 1 | +1 |
| Free Move | Rare | Move the top card 2× per turn | ✗ |
| Mise Master | Rare | Mise en Place also triggers if the hand has ≤ 1 ingredient | ✗ |
| Plating Pro | Rare | Garnish max +2 → +4 Quality | ✗ |

### 5.4 Rival thresholds

| Rival | Threshold |
|---|---|
| Tony, Rosa | 3 → 4 → 5 |
| Marco | 2 → 4 → 5 |
| Élodie, Bruno | 2 → 3 → 4 (same as the player) |

### 5.5 Implementation status (phase E)
- ✅ Data: `ModifierDef` (Resource) + 10 files in `data/modifiers/`. Numbers (`amount`), rarity, icon, text, `stackable` and build `tag` can be set in the Inspector; the effects are coded per `id` in `Duel`.
- ✅ Logic (`Duel` + `Kitchen`): Flow +1 only from a Perfect Order Serve (after the `dish_served` signal), player threshold `Duel.PLAYER_FLOW` 2→3→4, rival `EnemyDef.flow_thresholds` (Tony/Rosa default 3→4→5). All per duel (a new Kitchen every duel).
- ✅ Offers (`Duel._make_offer`, streams `offers`/`offers_enemy`): 2 Common + 1 slot (Rare 25%), pity 3 offers without a Rare → slot 3 Rare, no duplicates, no already-owned non-stackables. **Build** = a tag with ≥3 ingredients in the deck: a tagged modifier only appears if the deck uses that tag, and when one exists it always fills 1 slot.
- ✅ Player: `flow_offer` signal, the `FlowPick` overlay in `duel_ui.tscn` appears 1.2 s after Serve (after the dish reveal). While open, all actions are rejected ("Pick a modifier first.") and HUD input is locked. `pick_modifier(id)`.
- ✅ Rival: `RivalAI.pick_modifier` chooses according to its profile; its Serve step carries the `modifier`, then the Turn Director shows the banner **"TONY GOT / HOT PAN!"**.
- ✅ HUD: `PlayerFlow` / `EnemyFlow` rows (FLOW ●●○ + modifier chips with stack count and tooltip).
- Adjustments to the §5.3 table:
  - **Hot Pan** applies on every Serve, since Serve is only once per turn anyway.
  - **Plating Pro**: the rules have no Garnish cap yet, so the effect is "Garnish Quality ×2".
  - **Free Move**: the AI does not use card moves yet, so it is low-value for the rival.
- ✅ Balancing (phase G, §8.2): the player threshold was lowered to 1 → 2 → 3. A careful player now gets ±1 modifier per duel (was 0.06–0.22).

---

## 6. Almanac — ✅ done 23 Nov (phase F), see §6.5

### 6.1 Contents

| Tab | Entries | Data per entry |
|---|---|---|
| **Ingredients** | All ingredients (±15) | Tag, Quality, effect, recipes that use it |
| **Techniques** | All techniques | Cost, effect |
| **Recipes** | All recipes (±13) | **Perfect order** (ingredient icons bottom → top), base effect, source book, mastered status |
| **Rivals** | 5 rivals | Portrait, gimmick (unlocked after fighting them), recipes they have served |
| **Keywords** | Statuses + Perfect/Cooked/Garnish/Improvised | The existing tooltip text (`keywords.gd`) |

### 6.2 Discovery

| An entry unlocks when… | |
|---|---|
| Ingredient/technique | The card has been in your deck, or was offered as a reward/shop item |
| Recipe | You master its book (fully unlocked), **or** a rival serves it (unlocked, tagged "Seen from Tony"), or its book was seen in the Shop |
| Rival | When the duel starts (gimmick unlocks after the duel ends) |

Locked entries: a silhouette + "???" + a hint ("Found in Spice Route Journal").

**Persistence:** discovery is saved across runs (`user://almanac.save`). This is **knowledge, not power**, so it does not contradict the "no meta-progression" decision (GDD §11).

### 6.3 Combination finder
In the Recipes tab: click 1–3 tag/ingredient icons → a list of recipes that use them, with the missing steps highlighted. Only shows recipes that are already unlocked.

### 6.4 Access
- A book button (`book.svg` icon) in the HUD + the **Tab** key.
- In a duel: opening the Almanac **pauses** the game. It cannot be opened in the middle of the rival's turn animations (queued until the player's turn).
- In the Course Path / Shop: always openable.

### 6.5 Implementation status (phase F, 23 Nov)
- ✅ Logic: `Almanac` (`scripts/core/almanac.gd`, pure) stores cards, recipes (source `mastered` or a rival id), rivals (met / gimmick unlocked) and dishes served by rivals. `prepare(deck, books)` before the Recipe Book, `watch(duel)` during a duel: a rival is recorded when the duel starts, its recipes on Serve ("Seen from Tony"), its gimmick when the duel ends. A mastered book always beats "Seen from".
- ✅ Persistence: an `AlmanacKeeper` node in `main.tscn` (Inspector: `save_path` = `user://almanac.save`, `persist`, `reveal_all` for dev). Saved on every new discovery and when a duel ends (JSON).
- ✅ UI: the `Almanac` node in `duel_ui.tscn` (script `almanac_view.gd`). Ingredients / Techniques / Recipes / Rivals / Keywords tabs, a detail panel on the right, "???" silhouettes + hints for locked entries, a NEW badge (and a red dot on the HUD button) until the entry is viewed.
- ✅ Combination finder in the Recipes tab: choose up to 3 tags or key ingredients you have discovered. Only unlocked recipes; steps filled by your choice have a green frame, missing ones an orange frame.
- ✅ Access: a book button in the HUD (next to the pixel button), the **Tab** key, and an "Almanac (Tab)" button in the Recipe Book before a duel. Opening the Almanac pauses the game (`get_tree().paused`). On the rival's turn, Tab only queues: the Almanac opens when the player's turn begins. Tab / Esc / Close closes it.
- ✅ Data: `EnemyDef.gimmick` (gimmick text in the Rivals tab), filled in for Tony and Rosa.
- Adjustments: the Course Path and Shop do not exist yet, so "offered as a reward/shop" and "book seen in the Shop" discovery are unused. The Rivals tab only holds rivals that exist in the data (Tony, Rosa). Extra keywords (Perfect Order, Cooked, Garnish, Improvised Dish, Chef's Flow) are written in `AlmanacView.EXTRA_KEYWORDS`.

---

## 7. HUD changes

| Element | Position | Notes |
|---|---|---|
| Rival stations (3 stacks of card backs) | The rival's table, aligned with the player's stations | Contents cannot be hovered. Tooltip: "3 cards" |
| Rival hand | A small fan of card backs above the rival's table | Count only |
| Rival Heat | Pips next to the rival's portrait | |
| Chef's Flow | Small pips (●●○) under the Hype bar, per side | |
| Modifier row | Under the status row, per side | Icon + stack count, tooltip |
| Mood | The existing emote bubble | Replaces the Intent label |
| Almanac button | Top-right corner, near the pixel button | |
| Turn banner | Uses the announcer style (dark strip + slam text) | |

Extra assets for the ART_DIRECTION §8 list: a rival version of the card back (rival color), 2 new emotes (Wary), ±10 modifier icons, an Almanac frame + "???" silhouettes.

---

## 8. Implementation plan — ✅ phases A–G done 23 Nov

| Phase | Content | Depends on | Estimate |
|---|---|---|---|
| **A. Turn Director** | The `"enemy"` phase, `enemy_step` API, banners, input lock, fast-forward. The rival temporarily keeps using Intent through `enemy_step` | — | 1 day |
| **B. Symmetric Kitchen** | Refactor `Duel` into a per-side `Kitchen`, signals with `side`, `sim.gd` stays green | A | 1–1.5 days |
| **C. Rival AI** | `AiProfile`, candidate scoring, `preview_serve`, rival deck/books, face-down station visuals, mood | B | 2 days |
| **D. RNG** | Separate streams, anti-clump, Mise en Place + indicator | B | 0.5 day |
| **E. Chef's Flow** | Meter, pick-3 overlay, modifier pool, AI picks | B (C for the rival) | 1.5 days |
| **F. Almanac** | Data from `GameDB`, discovery + save, tab UI, combination finder | — (parallel) | 1.5 days |
| **G. Balancing** | `sim.gd`: AI vs AI hundreds of duels per rival, check duel length & win rate | C, D, E | 1 day |

Total ±9 working days, falling in week 2 of the GDD §10 schedule (29 Nov–5 Dec) with some spilling into week 3. **F can run in parallel** from the start.

**If the schedule slips, cut in this order:** combination finder → rival Flow thresholds → `trickster`/`showman` profiles (use `greedy`/`patient`) → the Rivals tab in the Almanac → Rare modifiers.

### 8.1 Tests
- `tests/sim.gd`: synchronous `run_enemy_turn()`; deterministic duels for the same seed (result snapshot).
- Visibility test: the UI never creates a `CardView` holding a rival card (card backs only).
- Fairness test: two runs with the same seed and different player decisions → the player's draw order stays the same (separate streams).
- Initial balancing target: Tony loses to the starter deck ±80% of the time (in the hands of a simple player AI), duels of 5–8 turns.

### 8.2 Balancing status (phase G, 23 Nov)
Tool: `tests/balance.gd` (headless) plays hundreds of duels per rival with two bots (`tests/balance_runner.gd`): **simple** (random cards, Serve anything that works = a new player) and **smart** (`RivalAI` on Apis's side = a careful player). `-- sweep` tries a grid of player Confidence × rival Confidence × Flow threshold. `tests/sim.gd` guards the targets (`_balance()`).

Initial problem: duels were too short (smart ±2.7 turns vs Tony), and Chef's Flow almost never triggered. Raising only the rival's Confidence made the player lose around turn ±6, because both sides deal ±10 Pressure per turn. So both sides were raised.

| Value | Before | Now | Where to change |
|---|---|---|---|
| Apis Confidence | 60 | **100** | `Duel.PLAYER_CONFIDENCE`, `Main` Inspector → Balance |
| Tony Confidence | 30 | **45** | `data/enemies/tony.tres` |
| Rosa Confidence | 38 | **50** | `data/enemies/rosa.tres` |
| Player Flow threshold | 2 → 3 → 4 | **1 → 2 → 3** | `Duel.PLAYER_FLOW`, `Main` Inspector → Balance |

Results (300 duels, starter deck):

| Rival | Bot | Win | Turns | Confidence left | Rival actions/turn | Apis modifiers/duel |
|---|---|---|---|---|---|---|
| Tony | simple | 76% | 7.5 | 38/100 | 4.8 (max 7) | 0.30 |
| Tony | smart | 98% | 4.7 | 64/100 | 4.8 | 1.00 |
| Rosa | simple | 38% | 6.3 | 34/100 | 4.2 (max 6) | 0.30 |
| Rosa | smart | 87% | 4.7 | 55/100 | 4.2 | 0.99 |

- The §8.1 target was met: Tony loses ±80% to a simple player, duels last 5–8 turns (a real player sits between the two bots). Rosa is harder than Tony for both bots.
- The §9 "rival turn length" risk: an average of 4.2–4.8 actions, under the limit of 6.
- Not yet: Marco, Élodie and Bruno are not in the data yet. Their Confidence in GDD §6.5 needs adjusting to the new scale when they are built (check with `balance.gd`).

---

## 9. Risks & open questions
- [x] **Rival turn length.** (Phase G: an average of 4.2–4.8 actions, see §8.2.) If the rival averages > 6 actions, the turn feels long. Mitigation: low rival Heat, merge "place 2 ingredients" into one animation.
- [ ] **AI too smart/dumb.** The profile weights need tuning via the sim (phase G).
- [ ] **Loss of telegraphing.** The mood + the card count on the rival's stations must be enough for defensive decisions. Check in the first playtest; if not enough, add a "ready glow" on rival stations that can be Served.
- [ ] **Élodie & the player's stations.** Her gimmick reads the *count* of cards on the player's stations (public), so it still fits the fairness promise.
