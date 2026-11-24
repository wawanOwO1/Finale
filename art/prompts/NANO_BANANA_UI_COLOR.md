# FINALE — Nano Banana prompts for UI color exploration

Goal: try several **color directions** for the whole duel UI without touching the layout. It works
**image-to-image**: upload a duel screenshot (1600×900) and ask Nano Banana to *only change the colors*.
The result is used as a visual reference, then the hexes are taken (with an eyedropper) and put into
`scripts/ui/pal.gd`. Explanations are for humans, **prompts are in English**.

This document complements `NANO_BANANA_2D.md` (that one is for making assets, this one is for choosing a palette).

---

## 0. Diagnosis of the current tone (from the screenshot)

| Element | Current color | Notes |
|---|---|---|
| Stage background | a peach → warm orange gradient | Bright, high saturation, competes with the cards |
| HUD panels (Player, Stations, Tony) | dark brown ~`#2a1f1a`, border `#3b2414` | Good contrast, but blends into the brown carpet below |
| Card rim | cream `#d9cdb8` | Safe |
| Cost block / Technique art | teal `#2f6f7a` | The only strong cool accent |
| HP bar, END TURN, discard counter | red `#d8342c` | **Three elements with different functions use the same red**, so the CTA does not stand out from the HP |
| Draw pile counter | blue `#3f7fae` | A pure blue feels "foreign cold" in a warm world |
| Highlight / active button | gold `#f2b632` | Good, but rarely used |

The questions the exploration should answer: (1) does the background need to be calmer so the cards and panels
stand out, (2) does the CTA (END TURN) need its own color, different from HP/danger,
(3) should the warm-orange world be kept or replaced with another mood.

---

## 1. How to use

1. Upload the duel screenshot as the first image. Use a **16:9 aspect ratio**.
2. Paste the **BASE PROMPT (§2)**, then replace the `{DIRECTION}` block with one of the directions in §3.
3. Generate 3–4 times per direction, and pick the cleanest. Text in the image sometimes drifts slightly, which is normal
   for exploration. Only **color and contrast** are judged.
4. If you like one, upload the result again and continue with a revision prompt (§5).
5. Compare all the results side by side at a **small size** (about 25%). A good UI still reads there.
6. For the chosen direction: take the hex of each role in the §3 table with an eyedropper, then update `pal.gd`.

---

## 2. BASE PROMPT (recolor, layout locked)

```
Recolor the attached game screenshot. This is a pixel-art cooking-show deckbuilder UI.

KEEP EXACTLY THE SAME: the layout, every panel, card, button, bar, icon, character, text, font, pixel
grid, outlines and shapes. Do not move, resize, add or remove anything. Do not redraw, restyle,
smooth or anti-alias. Keep crisp hard square pixels.

CHANGE ONLY THE COLORS, following this color direction:
{DIRECTION}

Color roles to respect:
- Stage background (behind everything): the main atmosphere color.
- HUD panels and station panels: dark, clearly separated from both the background and the floor strip.
- Card rim: light paper tone. Card body: dark.
- END TURN button: the single strongest call-to-action color on screen, different from the HP bar.
- HP / health bars: their own color, different from END TURN.
- Draw pile counter (left) and discard pile counter (right): two distinct, harmonious colors.
- Technique cards and cost blocks: the cool accent color.
- Selected / hovered highlight: bright accent (gold or equivalent).
Keep all text perfectly readable with strong contrast against its background.
Output the full screenshot at the same 16:9 framing.
```

---

## 3. Color directions (fill in `{DIRECTION}`)

Each direction has a palette with the same **roles**, so it is easy to map to `pal.gd`.

### A. Night Market (a market at night, lantern light)
The background becomes an indigo-blue night, and the warmth comes from the accents. Cards and panels stand out the most.
```
NIGHT MARKET. A street food market at night. Stage background: deep indigo to dusk violet gradient
(#1d1b3a to #3a2a5c) with a few warm lantern-orange glow spots (#e07b28). HUD panels: very dark
blue-black (#14122a) with a muted plum border (#3a2a5c). Card rim: warm cream (#f3e3c4), card body
dark (#1b1830). END TURN: glowing lantern orange (#e8892a) with a cream label. HP bar: fresh mint
green (#4fd18b). Draw counter: teal (#2f8f9a). Discard counter: crimson (#c2383f). Technique and cost
blocks: cyan-teal (#3fb6c4). Highlight: lantern gold (#f2b632).
```

### B. Retro Diner (teal, cream, cherry red)
A cool, fresh world with cherry red as the only hot accent.
```
RETRO DINER. 1950s diner palette. Stage background: soft aqua mint (#9fd8cf) to pale cream (#f3ead2).
HUD panels: deep teal-charcoal (#16363a) with a darker teal border (#0f2528). Card rim: cream
(#fbf3e2), card body: dark teal-black (#12262a). END TURN: cherry red (#d8342c) with cream label.
HP bar: butter yellow (#f2c94c) over a dark track. Draw counter: sky blue (#3f7fae). Discard
counter: tomato orange (#e0592b). Technique and cost blocks: teal (#2f8f8a). Highlight: bright butter
yellow (#f6d44a).
```

### C. Matcha Izakaya (matcha green, vermilion)
Calm and natural, with a little vermilion for emphasis.
```
MATCHA IZAKAYA. Japanese street-food stall palette. Stage background: soft matcha green (#b9c98a)
to warm rice-paper cream (#efe6c8). HUD panels: dark forest charcoal (#1f2a1f) with a mossy border
(#34462f). Card rim: rice-paper cream (#f1e8cf), card body: dark ink (#1a1f1a). END TURN: vermilion
red-orange (#d9482b) with cream label. HP bar: bright leaf green (#6fbf4a). Draw counter: indigo blue
(#3b5b8c). Discard counter: dusty plum (#8a4a6a). Technique and cost blocks: jade teal (#2f7f73).
Highlight: warm gold (#e8b83a).
```

### D. Bistro Burgundy (wine, gold, cream) — a luxurious cooking show
Feels premium, like an expensive TV stage.
```
BISTRO BURGUNDY. Upscale TV cooking show. Stage background: warm wine burgundy (#6e2a35) fading to
rose-tan (#c98c7a), soft spotlight in the center. HUD panels: very dark aubergine (#231418) with a
brass border (#8a6a3a). Card rim: ivory (#f6ecd6), card body: dark espresso (#1e1412). END TURN:
rich gold (#e8b83a) with a dark burgundy label. HP bar: emerald green (#3fa66a). Draw counter: slate
teal (#3f7a8a). Discard counter: deep crimson (#a8231d). Technique and cost blocks: peacock teal
(#2f7a86). Highlight: bright champagne gold (#f6d77a).
```

### E. Slate & Neon Orange (maximum contrast, UI-first)
A dark neutral world where only the accents are colored. The most readable.
```
SLATE AND NEON ORANGE. High-readability palette. Stage background: calm desaturated slate blue-grey
(#3b4252 to #5a6478), low saturation so cards pop. HUD panels: near-black charcoal (#161a22) with a
grey-blue border (#2a3140). Card rim: warm white (#f5efe2), card body: dark graphite (#1c2029).
END TURN: vivid orange (#ff7a1a) with a dark label. HP bar: lime green (#7ed957). Draw counter: cool
blue (#4a90d9). Discard counter: magenta-red (#d9435a). Technique and cost blocks: teal (#2fb3a8).
Highlight: electric yellow (#ffd23a).
```

### F. Candy Studio (bright pastel, a kids' TV show)
Friendly, cheerful, medium-high saturation.
```
CANDY STUDIO. Bright cheerful kids cooking show. Stage background: pastel peach-pink (#ffc9b5) to
butter yellow (#ffeaa0). HUD panels: warm dark cocoa (#3a2230) with a berry border (#6a3a52). Card
rim: milk white (#fff6e6), card body: dark cocoa (#2a1a24). END TURN: hot pink (#ff4f8b) with white
label. HP bar: mint green (#58d68d). Draw counter: bubblegum blue (#4aa8e8). Discard counter: grape
purple (#8a5ad6). Technique and cost blocks: turquoise (#2fbfb0). Highlight: sunshine yellow (#ffd23a).
```

### G. Sunset Synthwave (purple, pink, orange)
Bold and different from the market theme. Good if the game should feel like a "show".
```
SUNSET SYNTHWAVE. Stage background: dusk gradient from deep purple (#2a1a4a) through magenta pink
(#c2448a) to orange (#ff9a4a) near the horizon. HUD panels: dark violet-black (#1a1230) with a purple
border (#4a2a7a). Card rim: pale lilac-cream (#f3e6f0), card body: dark violet (#1e1430). END TURN:
hot magenta (#ff3d8b) with white label. HP bar: neon cyan-green (#3df0b0). Draw counter: electric
blue (#4a7cff). Discard counter: orange-red (#ff5a3a). Technique and cost blocks: cyan (#2fd0e0).
Highlight: bright yellow (#ffd23a).
```

### H. Control: Market Street (the current palette, tidied up)
For comparison. Solves the problem of 3 red elements and a background that is too bright.
```
MARKET STREET REFINED. Keep the warm world but calmer. Stage background: muted warm apricot (#e8b58a)
to sand (#f0d9b0), lower saturation than now. HUD panels: dark walnut (#2a1a10) with a lighter wood
border (#5a3722). Card rim: cream (#d9cdb8), card body: dark (#241d19). END TURN: golden amber
(#f2b632) with a dark brown label. HP bar: leaf green (#5ea44f). Draw counter: teal (#2f6f7a).
Discard counter: brick red (#a8231d). Technique and cost blocks: teal (#2f6f7a). Highlight: bright
gold (#ffd24a).
```

### Role table (fill in after choosing, then move to `pal.gd`)

| Role | Night Market | Retro Diner | Matcha | Burgundy | Slate Neon | Candy | Synthwave | Refined |
|---|---|---|---|---|---|---|---|---|
| Background top | `#1d1b3a` | `#9fd8cf` | `#b9c98a` | `#6e2a35` | `#3b4252` | `#ffc9b5` | `#2a1a4a` | `#e8b58a` |
| Panel | `#14122a` | `#16363a` | `#1f2a1f` | `#231418` | `#161a22` | `#3a2230` | `#1a1230` | `#2a1a10` |
| Card rim | `#f3e3c4` | `#fbf3e2` | `#f1e8cf` | `#f6ecd6` | `#f5efe2` | `#fff6e6` | `#f3e6f0` | `#d9cdb8` |
| END TURN CTA | `#e8892a` | `#d8342c` | `#d9482b` | `#e8b83a` | `#ff7a1a` | `#ff4f8b` | `#ff3d8b` | `#f2b632` |
| HP | `#4fd18b` | `#f2c94c` | `#6fbf4a` | `#3fa66a` | `#7ed957` | `#58d68d` | `#3df0b0` | `#5ea44f` |
| Cool accent | `#3fb6c4` | `#2f8f8a` | `#2f7f73` | `#2f7a86` | `#2fb3a8` | `#2fbfb0` | `#2fd0e0` | `#2f6f7a` |
| Highlight | `#f2b632` | `#f6d44a` | `#e8b83a` | `#f6d77a` | `#ffd23a` | `#ffd23a` | `#ffd23a` | `#ffd24a` |

---

## 4. Additional prompts

### 4.1 Free moodboard (to see directions outside the list)
```
Create a 3x2 grid of six color-palette mood panels for the UI of a pixel-art cooking-competition
deckbuilder. Each panel shows: one large background swatch, one dark UI-panel swatch, one cream card
swatch, one bright call-to-action button swatch, one health-bar swatch, and one cool accent swatch,
arranged as simple flat rectangles. Six different moods: night market, retro diner, matcha, burgundy
bistro, candy pastel, neon synthwave. No text, no labels, no gradients inside swatches.
```

### 4.2 Just the palette from a result you like
Upload the chosen recolor result:
```
From the attached screenshot, extract the 10 most important UI colors and show them as a single
horizontal row of 10 flat square swatches on a plain white background, ordered: background top,
background bottom, HUD panel, panel border, card rim, card body, call-to-action button, health bar,
cool accent, highlight. No text.
```
Then eyedropper each swatch (or ask Claude to read the hex from that image).

### 4.3 Isolated components (check that the palette holds up on small elements)
Upload the chosen recolor result:
```
Using the exact color palette of the attached screenshot, show an isolated UI kit on a flat
neutral-grey background: one player HUD panel with an empty health bar, one card in Ingredient style
and one card in Technique style, one END TURN button, one draw-pile counter and one discard-pile
counter, one gold highlight frame. Same pixel-art style, hard square pixels, no text.
```

---

## 5. Revision prompts (when the result misses)

| Problem | Resend |
|---|---|
| The layout/text changed | `You changed the layout. Redo it and keep every element, position and shape pixel-identical to the first image. Change colors only.` |
| It became smooth / painting-like | `Strictly pixel art. Hard square pixels, no gradients, no soft shading, no blur. Same pixel grid as the original.` |
| END TURN does not stand out enough | `Make END TURN the single most saturated, brightest element on screen. No other button or bar may use its hue.` |
| HP and END TURN still look alike | `The HP bar and the END TURN button must be clearly different hues. Change the HP bar only.` |
| The background competes with the cards | `Lower the saturation and brightness of the stage background by 30 percent so the cards and panels stand out. Do not touch anything else.` |
| The panels blend into the bottom floor | `Make the HUD panels slightly darker than the bottom floor strip so their edges are clearly visible.` |
| Text is hard to read | `Increase contrast of all text against its background. Keep text pixel-identical, change only the colors behind it.` |
| Too many colors | `Reduce the palette to at most 12 colors total. Merge similar hues.` |
| Want a mix of two directions | `Take the background and panels from image 1 and the button, bar and counter colors from image 2.` |

---

## 6. Checklist

- [ ] Generate 3 variations of each direction A–H (D–G are optional if time is short)
- [ ] Lay them side by side and view at 25% size
- [ ] Pick 1–2 directions, do the §5 revisions
- [ ] Extract the palette (§4.2) and check text vs panel contrast
- [ ] Update `scripts/ui/pal.gd` + the stage background in `main.tscn`, test with `tests/ui_drive.gd`
