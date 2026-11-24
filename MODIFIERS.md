# MODIFIERS — List & Rules of Chef's Flow Modifiers

A reference document for every **modifier** in FINALE. The source of truth for the numbers is `godot/data/modifiers/*.tres`
(editable in the Inspector); the effects are coded per `id` in `godot/scripts/core/duel.gd`.
The initial design is in `GRAND_DESIGN.md` §5. In-game text is in English.

---

## 1. What a modifier is

- A **temporary power-up per duel**, not permanent between duels. Modifiers and Chef's Flow reset every new duel
  (the Kitchen is created anew each duel). What is permanent for the whole run is the Kitchen Tool (GDD §6.4), not the modifier.
- Obtained through **Chef's Flow**: every **Perfect Order** Serve = +1 Flow. A Cooked or Improvised Serve = +0.
- When Flow reaches the threshold, Flow returns to 0 and a **pick 1 of 3 modifiers** appears.
- Both the player and the rival can get modifiers. The rival picks automatically through `RivalAI.pick_modifier`.
- There is no RNG in a modifier's effect: damage, Quality and buffs are always certain. RNG exists only in the **offers**
  (streams `offers` / `offers_enemy`, following the duel seed, so they can be reproduced).

### Flow thresholds

| Side | Threshold (Perfect Serves per modifier) | Where to change |
|---|---|---|
| Player (Apis) | **1 → 2 → 3**, then stays at 3 | `Duel.PLAYER_FLOW`, `Main` Inspector → Balance |
| Rival (default) | **3 → 4 → 5**, then stays at 5 | `EnemyDef.flow_thresholds` (`data/enemies/*.tres`) |

The design's initial threshold was 2 → 3 → 4. Phase G (balancing) lowered it to 1 → 2 → 3 because Flow almost
never triggered (GRAND_DESIGN §8.2). The existing rivals (Tony, Rosa) use the default. Marco, Élodie and Bruno are not
in the data yet, so the thresholds in GRAND_DESIGN §5.4 only apply once they are built.

---

## 2. Modifier list (10)

Card text uses `X` in place of a number. The number `X` = `amount` × the number of stacks.

### Common (7)

| Modifier | id | In-game text | Amount | Stack | Build tag |
|---|---|---|---|---|---|
| **Hot Pan** | `hot_pan` | Every Serve deals +X Pressure. | 3 | Yes (+3 / stack) | — |
| **Steady Hands** | `steady_hands` | +X Composure each time you place an ingredient. | 1 | Yes (+1 / stack) | — |
| **Encore** | `encore` | Perfect Order multiplier +X. | 0.25 | Yes (+0.25 / stack) | — |
| **Extra Burner** | `extra_burner` | After a Perfect Order Serve, +X Heat next turn. | 1 | No | — |
| **Prep Cook** | `prep_cook` | Draw +X card at the start of each turn. | 1 | No | — |
| **Crowd Favorite** | `crowd_favorite` | +X Hype on every Serve. | 10 | Yes (+10 / stack) | — |
| **Spice Whisperer** | `spice_whisperer` | Placing a SPICE ingredient gives the rival Spicy X. | 1 | Yes (+1 / stack) | `SPICE` |

### Rare (3)

| Modifier | id | In-game text | Amount | Stack | Build tag |
|---|---|---|---|---|---|
| **Free Move** | `free_move` | Move a top card up to X times per turn. | 2 | No | — |
| **Mise Master** | `mise_master` | Mise en Place also helps when your hand has only 1 ingredient. | 1 | No | — |
| **Plating Pro** | `plating_pro` | Garnish gives xX Quality. | 2 | No | — |

Icons: Hot Pan `heat`, Steady Hands `composure`, Encore `check`, Extra Burner `heat`, Prep Cook `draw`,
Crowd Favorite `hype`, Spice Whisperer `spicy`, Free Move `arrow`, Mise Master `inspired`, Plating Pro `crown`.

---

## 3. How each modifier works

| Modifier | When it is active | Exact effect | Code |
|---|---|---|---|
| **Hot Pan** | Every Serve, after the dish is resolved | Adds flat Pressure to the opponent: `3 × stack`. Applies on **every** Serve (the initial design said "the first Serve each turn"; the same thing, since Serve is only once per turn). Does not run if the duel is already over. | `Duel.serve_bonus`, `serve()` |
| **Steady Hands** | Each time an ingredient is placed on a station | +`1 × stack` Composure. Techniques do not trigger it. | `play_card` |
| **Encore** | When computing the Serve multiplier | The Perfect Order multiplier becomes `1.5 + 0.25 × stack` (stack 1 = ×1.75, stack 2 = ×2.0). | `Duel.perfect_mult` |
| **Extra Burner** | A Perfect Serve, used at the start of the next turn | Next turn's Heat +1 above the maximum. One use per trigger, does not stack. | `serve()`, `_start_turn` |
| **Prep Cook** | The start of every turn | Draw +1 card above the normal hand size. | `_start_turn` |
| **Crowd Favorite** | Every Serve | +`10 × stack` Hype, on top of the recipe's Hype. Speeds up the Signature Dish. | `serve()` |
| **Spice Whisperer** | Each time a `SPICE`-tagged ingredient is placed | The opponent gets Spicy `1 × stack`. Only offered to decks that have a `SPICE` build. | `play_card` |
| **Free Move** | The move-top-card action | The per-turn move allowance becomes 2 (instead of 1). | `Duel._move_left` |
| **Mise Master** | After the turn-start draw | Mise en Place (bad-luck protection) also triggers when the hand has ≤ 1 placeable ingredient, not only 0. Still max 1× per turn. | `Duel._mise_en_place` |
| **Plating Pro** | When computing the dish's Quality | The Quality from Garnish cards (cards on the plate beyond the recipe's ingredients) is multiplied by 2. The initial design said "Garnish max +2 → +4", but the rules have no Garnish cap yet, so it was replaced by ×2. | `Duel.dish_quality` |

---

## 4. Offers (pick 1 of 3)

Made in `Duel._make_offer(side)`:

1. **Composition**: 2 Common slots + a 3rd slot (Rare 25%, Common 75%).
2. **Rarity pity**: after 3 consecutive offers without a Rare (`RARE_PITY`), the 3rd slot is guaranteed to be Rare.
3. **No duplicates** within one offer.
4. **Already-owned non-stackables** are not offered again. Stackable ones may reappear and add a stack.
5. **Build match**: a build = an ingredient tag with ≥ 3 cards in the deck. A tagged modifier (currently only
   Spice Whisperer, tag `SPICE`) only appears if the deck uses that tag. If one matches, at least 1 of the 3
   is that tagged modifier (filling the first Common slot).
6. **Thin pool**: if there are fewer than 3 candidates, the rest is filled from whatever remains. If it is empty,
   there is no offer and Flow is still reset.

UI flow for the player: the `FlowPick` overlay appears ±1.2 seconds after the Serve (after the dish reveal). While the overlay
is open all actions are rejected with the message "Pick a modifier first." and HUD input is locked.

---

## 5. Rival & modifiers

- The rival picks modifiers automatically. Each modifier's value is computed by `RivalAI.modifier_value` from its profile's weights:

| Modifier | Value to the rival |
|---|---|
| Hot Pan | `amount × w_attack` |
| Steady Hands | `amount × 2.5 × w_defend × 2` |
| Encore | `amount × 10 × w_attack` |
| Extra Burner | 2.0 |
| Prep Cook | 2.5 |
| Crowd Favorite | 0.3 (1.5 for the player) |
| Spice Whisperer | `amount × 2 × w_debuff` |
| Free Move | 0.1 (1.0 for the player) |
| Mise Master | 1.5 |
| Plating Pro | `1.5 + hand size × 0.1` |

- Free Move is low-value for the rival because the AI does not use the move-card action yet.
- When the rival takes a modifier, the Turn Director shows a banner (e.g. **"TONY GOT / HOT PAN!"**, 1 second)
  and the icon enters the rival's modifier row in the HUD.

---

## 6. HUD display

- The `PlayerFlow` / `EnemyFlow` rows in `scenes/ui/duel_ui.tscn`: FLOW pips (●●○) under the Hype bar, then a modifier
  chip with an icon, stack count and tooltip (`ModifierDef.describe(stacks)`).
- Icons come from `res://assets/icons` and are tinted.
- The modifier-pick overlay (`FlowPick`): 3 choices, with text from `ModifierDef.describe()`.

---

## 7. Adding or changing a modifier

**Changing numbers** (no code): open `godot/data/modifiers/<id>.tres` in the Inspector and change `amount`, `rarity`,
`stackable`, `icon`, `text` or `tag`.

**Adding a new modifier:**
1. Create a new `.tres` in `godot/data/modifiers/` with the `ModifierDef` script (copy an existing one). The `id` must be unique.
   `GameDB` loads every file in that folder and sorts them by `id`, so the offer order stays deterministic.
2. Code its effect in `duel.gd` with `mods(side, "<id>")` at the right point (see the §3 table).
3. Add the AI value in `RivalAI.modifier_value`. Without this the modifier is worth 0 and the rival will never pick it.
4. If the modifier is only useful for a certain build, set `tag` to the ingredient tag (for example `SPICE`).
5. Add a test in `godot/tests/sim.gd` and run it; after that check the impact on balance with `tests/balance.gd`.

Note: `ModifierDef.describe()` replaces `X` in `text` with `amount × stack`. For Plating Pro, the text "xX"
means "×2" (a lowercase `x` followed by the number).

---

## 8. Balance notes

From GRAND_DESIGN §8.2 (300 duels, starter deck, player threshold 1 → 2 → 3):

| Rival | Bot | Win | Apis modifiers / duel |
|---|---|---|---|
| Tony | simple | 76% | 0.30 |
| Tony | smart | 98% | 1.00 |
| Rosa | simple | 38% | 0.30 |
| Rosa | smart | 87% | 0.99 |

A careful player gets ±1 modifier per duel. The main lever for modifier frequency is the Flow threshold
(`Duel.PLAYER_FLOW`), not the per-modifier numbers. Per-modifier balancing (for example high stacks of Encore or Hot Pan)
has not been done; what `tests/balance.gd` has measured so far is only the number of modifiers per duel.
