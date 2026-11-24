# FINALE — Character Plan (Blender → GLB → Godot)

> Companion to [ART_DIRECTION.md](ART_DIRECTION.md) §2.3 and §8. Written 23 Nov 2026.
> The three reference images (a wide-hatted wizard, a big-eyed white creature, a leafy sprite) are **guidance for feel only**.
> No characters, distinctive shapes or colors are copied. Every character below is an original Finale design.

## 0. Decisions (23 Nov)

| # | Question | Decision |
|---|---|---|
| 1 | Species | **Masked chibi humans**: still human (hair, clothes, hands, feet), with the face simplified into a cream "mask" |
| 2 | Proportions | **1:2** (the head is half the body height). Replaces 1:3 in ART_DIRECTION §2.3 |
| 3 | Audience | **4 base meshes** + recolored in Godot |
| 4 | Roster | **Apis + 5 rivals**: Tony, Rosa, Marco, Élodie, Bruno |

---

## 1. Style bible: a blend of 3 references

| From the reference | What is taken | What is **not** taken |
|---|---|---|
| The hatted wizard (ref 1) | **Faceted** low-poly, flat shading with no textures, a calm warm palette, a **silhouette defined by the hat/robe**, small thin legs | The wide wizard hat + dark robe + single eye (their design) |
| The white creature (ref 2) | A **big round head**, **big oval black eyes**, small pink blush, cute short hands and feet, a little "odd but cute" | The plain white body, the brush texture |
| The leafy sprite (ref 3) | A **cream mask face** separate from the head, dark oval eyes, a round bean-shaped body, **mitten hands** with no fingers, short chubby legs, matte pastel colors, soft toon shading | The leaf hat + stem, the beak nose, wings/tail |

**The Finale character formula**
- **Head (50%)**: a slightly elongated sphere. On the front is a cream (`#f3e3c4`) **face mask** attached like a shallow plate, slightly protruding from the head. The mask: **2 big black oval eyes** set wide apart and a little low, small pink **blush** marks under the eyes, **no mouth, no nose**. Expression comes from the emote bubble (ART_DIRECTION §5), so the 3D face stays neutral.
- **Hair / hat**: a big low-poly block above the mask. This is each character's **main differentiator** and must read from the high camera.
- **Body (35%)**: a round bean-shaped torso, with clothes and apron as big color zones.
- **Legs (15%)**: short, with simple shoes/boots.
- **Hands**: round mittens with no fingers. Short arms.
- **Shading**: faceted flat, 1 warm light from the upper left, no outline in the image (the outline comes later from the Godot shader).
- **Color**: at most 5 color zones per character, from the "Market Street" palette (ART_DIRECTION §3.1).

---

## 2. Using the prompts in Nano Banana

1. Each prompt = **STYLE BLOCK** + **CHARACTER BLOCK** + **OUTPUT BLOCK**. Copy all three in order.
2. Make **Apis first**. Once the result is right, use the Apis image as the **reference image** for every following character, with the extra sentence:
   `Use the attached image only as the style and proportion reference. Same rendering, same head-to-body ratio, same mask face. Create a different character:`
3. Do not attach the 3 original reference images to Nano Banana. The style is already described in the STYLE BLOCK, so the results stay original.
4. If the pose result is off, redo it with the sentence: `Redo in a strict front orthographic view, symmetrical A-pose, arms away from the body.`
5. Save results in `art/concepts/characters/<name>_front.png` (a folder outside `godot/` so it is not imported).

### STYLE BLOCK (the same for all)
```
Stylized low-poly 3D character, chibi proportions with a 1:2 head-to-body ratio (the head is as tall as the rest of the body).
Faceted flat-shaded polygons, matte colors, no textures, soft toon lighting from the upper left, gentle ambient occlusion.
Muted warm cozy palette, maximum five color areas on the character.
The face is a smooth cream-colored mask-like plate on the front of the head: two large glossy black oval eyes set wide apart and slightly low, tiny soft pink blush marks under the eyes, no mouth, no nose, no eyebrows.
Round bean-shaped torso, short stubby arms with rounded mitten hands without fingers, short legs with simple small shoes.
Cute, slightly whimsical, readable silhouette, designed to be rebuilt as a game model in Blender.
```

### OUTPUT BLOCK (the same for all)
```
Full body, strict front orthographic view, perfectly centered and symmetrical, neutral A-pose with arms angled 30 degrees away from the body and legs slightly apart, standing straight, looking at the camera.
Nothing held in the hands, no props touching the body.
Plain flat light grey background (#d0d0d0), no floor, no shadow on the background, no text, no logo, no watermark, no frame.
Square 1:1 image, the character fills about 85% of the image height.
Avoid: realistic human face, mouth, nose, fingers, outlines, cel-shading ink lines, pixel art, painterly brush texture, dynamic pose, perspective camera, side view, three-quarter view, multiple characters.
```

> Props (a spoon, a pizza peel, a meat cleaver, a cream bag) are made **separately** in Blender and attached to the hand bone. That is why the characters are made empty-handed.

---

## 3. Main character

### 3.1 Apis Tetrarch — MC
A young cook from a small family kitchen, an underdog. "Apis" = bee, so there is a subtle touch of honey.
Silhouette: **a short floppy toque tilted to one side** + a fluttering bandana tail.

```
CHARACTER: Apis, a young underdog cook from a small family kitchen.
A short soft chef toque that flops to the left side, with a mustard-yellow (#f2b632) band around it and two short bandana tails sticking out behind the head.
A few messy dark brown (#3b2414) hair tufts peeking out under the toque above the mask.
A teal (#2f6f7a) neckerchief tied at the front.
A cream (#fbf3e2) cook jacket with rounded collar, covered by an oversized hand-me-down apron in warm wood brown (#7a4e30) that reaches the knees, with one small square patch sewn on the apron and one small hexagon honey-shaped pocket.
Short dark brown pants, small mustard-yellow shoes.
Mood: earnest, hopeful, a little scrappy.
```

---

## 4. Rivals (Market Street)

Scale in Blender is relative to Apis (= 1.0). Different sizes help convey the opponent's "class".

| Rival | Scale | Key silhouette | Main colors |
|---|---|---|---|
| Tony | 0.95 | Headband + a tuft of hair + a towel on the shoulder | Red, white, slate |
| Rosa | 1.0 | A small paper crown over a bandana + 2 long braids | Hot red, orange, green |
| Marco | 1.1 | A tall pompadour + a curled moustache + a vest | Teal, cream, red |
| Élodie | 1.05 | A tall slim toque + a big ribbon + a flared pastry coat | Cream, pale pink, light blue, brown |
| Bruno | 1.45, wide body | A heavy iron visor + a thick leather apron + big shoulders | Dark iron, old wood, ember orange |

### 4.1 Tony — street noodle cook (Duel, tutorial)
```
CHARACTER: Tony, a laid-back street noodle cook, the easy first opponent.
A red (#d8342c) cloth headband tied around the forehead above the mask with the knot and two short tails on the right side.
A tall spiky bundle of black hair sticking up out of the headband like a broom.
A white sleeveless undershirt, a small white towel draped over the left shoulder.
Loose slate-blue (#3f7fae) knee-length shorts tied with a rope belt, simple wooden sandals.
Slightly round belly.
Mood: relaxed, cheeky, overconfident.
```

### 4.2 Rosa — taco truck queen (Duel, trickster)
```
CHARACTER: Rosa, a quick-witted food truck queen who loves teasing her opponents.
A small gold-yellow (#f2b632) paper crown with three points pinned on top of a hot red (#d8342c) bandana.
Two long thick dark brown braids hanging over the front of the shoulders, each ending in a small green (#4d9a4a) chili-pepper-shaped hair tie.
Large round gold hoop earrings.
A short cropped orange (#e07b28) work jacket with rolled sleeves over a cream top, a short dark red half-apron around the waist with two front pockets.
Dark brown pants, chunky red sneakers.
Mood: sly, playful, mischievous.
```

### 4.3 Marco — pizza showman (Duel, showman)
```
CHARACTER: Marco, a flamboyant pizza showman who loves an audience.
A very tall glossy black pompadour hairstyle swept up and forward like a wave above the mask.
A thin curled black moustache attached to the lower part of the mask, curling upward at both ends.
A teal (#2f6f7a) and cream vertical-striped showman vest with two big gold buttons, over a cream shirt with puffy short sleeves.
A large red (#d8342c) bow tie.
Slim dark brown trousers, shiny cream shoes.
Chest pushed out proudly.
Mood: theatrical, proud, show-off.
```

### 4.4 Élodie — rival pâtissière (Elite, patient)
```
CHARACTER: Élodie, an elegant and precise rival pastry chef.
A very tall slim cylindrical chef toque in cream (#fbf3e2) with a pale pink pleated band.
A neat short chin-length cocoa brown (#5a3722) bob haircut framing the mask, with a large pale blue (#8fb3d1) ribbon bow at the back of the head that is visible as two loops on both sides.
A long cream double-breasted pastry coat with two rows of small cocoa buttons, flaring out like a short cape below the waist down to the knees.
Pale pink gloves as mitten hands.
Small cocoa brown ankle boots.
Very straight upright posture.
Mood: calm, precise, quietly superior.
```

### 4.5 "Iron" Bruno — butcher-turned-grill master (Boss)
```
CHARACTER: "Iron" Bruno, a huge butcher turned grill master, the final boss.
Much wider and heavier than the other characters: broad round shoulders, barrel chest, thick arms, big mitten hands, short thick legs.
Over the upper part of the cream mask he wears a dark iron-grey (#3b3b44) visor shaped like a grill grate with three horizontal bars, so only the two black oval eyes show between the bars.
A short dark wood-brown (#2a1a10) buzz cut on top.
A thick dark leather apron (#5a3722) with big metal rivets, covering a rust-red (#a8231d) shirt with rolled sleeves.
Ember-orange (#e07b28) wrist wraps on both forearms.
Heavy dark boots.
Mood: intimidating, heavy, smoldering heat.
```

---

## 5. Audience (4 base meshes)

The audience is made simpler (lower low-poly, no full rig) and **recolored in Godot**. So each base has 3 fixed color zones:
- **Zone A** (main clothing), **Zone B** (accent: hat/scarf/hair), and the cream **mask** stays fixed.

In the prompts, zones A and B are given default colors. In Godot the colors are replaced per instance.

Addition to the audience OUTPUT BLOCK:
```
Simpler design than a main character: fewer details, bigger shapes, suitable for a low-poly crowd extra.
```

### 5.1 Crowd A — "Round Fan"
```
CHARACTER: a round, short, cheerful crowd member.
Very round chubby body in a chunky knit sweater (zone A, mustard #f2b632) and a small beanie hat with a pom-pom (zone B, teal #2f6f7a).
Short dark pants, small shoes.
Mood: excited, wholesome.
```

### 5.2 Crowd B — "Tall Hoodie"
```
CHARACTER: a tall, thin crowd member, taller than average but still chibi.
A long hoodie (zone A, slate blue #3f7fae) with the hood up, the hood has two small rounded cat-ear bumps on top (zone B, cream #f3e3c4 inner color).
Thin legs, simple sneakers.
Mood: shy, curious.
```

### 5.3 Crowd C — "Kid"
```
CHARACTER: a small child crowd member, about 70% the height of an adult chibi.
A big floppy bucket hat that is wider than the head (zone B, olive green #5ea44f).
A simple short-sleeved shirt (zone A, tomato red #d8342c), short shorts, round little shoes.
Mood: excited, wide-eyed.
```

### 5.4 Crowd D — "Elder"
```
CHARACTER: an old crowd member.
A grey hair bun on top of the head, a long knitted shawl wrapped around the shoulders like a small cape (zone B, dusty peach #e0a07a).
A long simple dress or coat (zone A, plum brown #6b4a32) reaching the ankles, slightly hunched posture.
Mood: warm, dignified.
```

---

## 6. Blender → Godot pipeline (plan, not yet done)

### 6.1 Modeling
| Item | Target |
|---|---|
| Apis's height | **2.3 m** in Blender (the same as the current `scenes/stage/chef.tscn` placeholder: body 1.6 + head), so the camera and stage do not need to change |
| Poly budget | Apis & rivals: **800–1500 tris**. Bruno: ≤ 2000. Audience: **300–600 tris** |
| Face | The mask = a separate, slightly protruding mesh. The eyes = black oval meshes (not a texture) so they stay sharp at 640×360 |
| Sides & back | The images only show the front, so depth and the back are decided while modeling. If needed, make a side-view prompt later from the finished front image |
| Origin | Between the feet, Z = 0 at the floor, facing −Y in Blender (so +Z in Godot) |

### 6.2 Color
- **One palette texture** of 24 colors (ART_DIRECTION §3.1), 32×32, nearest filter. Each zone's UV is snapped to one color square. One material for all characters, which suits the Compatibility renderer.
- Audience: zones A and B use marker **vertex colors** (red = A, green = B). A Godot shader replaces the colors with an `instance uniform` per audience member.

### 6.3 Rig & animation
- A simple armature: `root, hips, spine, head, hat, arm.L/R, hand.L/R, leg.L/R`. Audience: `root, body, head` only.
- Animations per chef (GDD §7.4): `idle`, `cook`, `hit`, `taunt`, `defeated`, `hop`. Audience: `idle`, `cheer` (can be procedural).
- Props are parented to `hand.R` through a `BoneAttachment3D` in Godot.

### 6.4 Export
- glTF Binary (`.glb`), **+Y Up**, Apply Transform, no cameras/lights, animations as NLA/Actions with the names above.
- Files: `godot/assets/models/characters/<name>.glb` (`apis`, `tony`, `rosa`, `marco`, `elodie`, `bruno`, `crowd_a`…`crowd_d`).
- In Godot: `chef.tscn` gets a `.glb` child instance replacing the Body/Head/Hat placeholder. `chef.gd` calls the `AnimationPlayer` for the flinch/hop that are still procedural. The crowd in `stage.gd` (`_spawn_crowd`) is replaced with audience nodes in the scene, following the "nodes in scenes" rule.

### 6.5 Work order
1. Generate the Apis front view → approve.
2. Generate the 5 rivals + 4 audience members with Apis as the style reference → approve.
3. Blender: model Apis + palette texture + rig + 1 `idle` animation → export → test in Godot with the outline shader and pixel filter. **This is the gate**: if it reads well at 640×360, continue.
4. Model the 5 rivals (starting with Tony & Rosa, who already exist in the data), then the audience.
5. Full animations, props.
6. Background/stage (a separate plan after the characters).
