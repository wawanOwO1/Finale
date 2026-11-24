# ANIMATION_DESIGN — Apis & Tony

The animation plan for the first two 3D characters (`apis.glb`, `tony.glb`). Made in Blender on top of the existing Mixamo skeleton,
then re-exported to Godot. This document replaces the temporary list in CHARACTER_PLAN §6.3
for Apis and Tony only.

## 1. Key decisions

| # | Topic | Decision |
|---|---|---|
| 1 | Clip list | **5 clips** per character: `idle`, `chop`, `busy`, `victory`, `lose`. The names are exactly the same for every chef so `chef.gd` only needs to call `play("idle")`. |
| 2 | Rig | The stock Mixamo skeleton (53 `mixamorig:*` bones). No re-rig, no IK. Key **rotation** per bone, plus **Hips position** for bob/jump. |
| 3 | In place | All clips are **in place**. The Hips only move up and down (Y) and shift slightly (≤ 3 cm). Chefs do not walk; their position on the stage is set by the scene. |
| 4 | Style | Chibi, cartoony: strong poses, **anticipation → action → hold**, ease in/out, a little overshoot. Motion must read at 640×360, so amplitude is made larger than realistic. |
| 5 | One source, two personalities | One pose script in Blender builds all five clips from the pose table. Each character has **style parameters** (tempo, amplitude, special poses), so Apis and Tony feel different without animating by hand twice. |
| 6 | Frame rate | **30 fps**. Key poses on even frames, Bezier interpolation. |
| 7 | Loop | `idle`, `chop`, `busy` = seamless loops (last frame = first frame). `victory`, `lose` = play once, stop on the final pose (Godot stays on the last frame). |
| 8 | Props | No knife/cutting board/pan in the GLB. The hand pose is prepared to hold a knife in the **right hand**. Props come later through a `BoneAttachment3D` on `mixamorig_RightHand`. |

## 2. Personalities

| | Apis (MC, underdog) | Tony (street noodle cook, laid-back, arrogant) |
|---|---|---|
| Base posture | Upright, shoulders slightly forward, ready to work | Slightly hunched, belly forward, shoulders dropped |
| Tempo | Normal, fast when working | Slower in `idle`, but shows off fast in `chop` |
| Amplitude | Medium, tidy | Big, loose, "flashy" |
| Signature | The head often glances at the hands (focus) | Head tilted, one hand on the hip when relaxed |

## 3. Clips

"Left/right" = the character's own body side. Durations are for Apis; Tony uses the tempo multipliers in §4.

### 3.1 `idle` — loop, 2.0 s (60 f)
Breathing and weight shifts, never truly still.

| Frame | Pose |
|---|---|
| 0 | Neutral: arms down relaxed (±70° from the T-pose), elbows slightly bent, Hips at rest height −1 cm. |
| 30 | Inhale: Spine1/Spine2 upright +3°, shoulders up 2°, head up 2°, Hips +1 cm. |
| 60 | = frame 0. |

A small layer: the head sways left-right 3° over a full period (offset by ¼ cycle) so it is not robotic.
**Tony:** 2.4 s, weight on the right leg (Hips tilted 4°), left hand on the hip, head tilted 6°.

### Easing (revision 2)

Every key can set easing on the segment **leading to** that key. This is what makes motion feel crisp instead of floaty:

| Easing | Blender | Used for |
|---|---|---|
| `in` | Cubic, ease-in | Accelerating toward an impact: the knife hitting, landing, dropping to the knees |
| `out` | Back, ease-out (overshoot 1.2) | Arriving at a pose then bouncing slightly: knife recoil, reaching a station, the victory pose |
| `snap` | Expo, ease-out | Leaving very fast then slowing: a startle, a jump, tossing the pan |

### 3.2 `chop` — loop, 1.2 s (36 f), a "chop, chop, CHOP" rhythm
The whole body joins in the chopping: leaning and dropping on every hit.

| Frame | Pose | Easing |
|---|---|---|
| 0 | **Raise**: the knife in the right hand at head height (upper arm raised to the side, elbow 120°), right shoulder up, body slightly upright. The left hand holds the ingredient in front of the belly. | |
| 4 | **Hit**: right hand straight down to the board, body leaning 10°+8°, head nodding, Hips down 3.5 cm. | `in` |
| 6 | A small recoil. | `out` |
| 10–16 | Repeat, the left hand shifts 6° sideways (sliding the ingredient). | |
| 24 | **Big raise**: the hand higher, body leaning back slightly. Tony glances at the crowd (head 22°). | |
| 28 | **Big hit**: Hips down 5.5 cm, body leaning 14°. | `in` |
| 31 | Recoil. | `out` |
| 36 | = frame 0. | |

**Tony:** tempo 0.85, amplitude ×1.15, hand raised higher, head not lowered.

### 3.3 `busy` — loop, 2.4 s (72 f)
Grab an ingredient on the left, put it in the pot in the middle, shake and toss the pan on the right. Small hops between stations.

| Frame | Pose | Easing |
|---|---|---|
| 0 | Center, working position. | |
| 4 | The head glances left first. | |
| 9 | **Arrive on the left**: body turns 50° total (Hips 35%, Spine 65%, feet turned back so they stay planted), Hips shift 3 cm. The right hand reaches far across the body, the left hand open for balance. | `out` |
| 14 | **Grab**: body ducks, crouches 3 cm, hand grips. | `in` |
| 19 | A small hop to the center (Hips +3 cm), carrying the ingredient. | `snap` |
| 24 | **Put it in the pot**: both hands forward-down, body leaning 16°, crouched. | `in` |
| 27 | Bounce. | `out` |
| 30 | The head glances right. | |
| 35 | **Arrive on the right**, holding the pan handle. | `out` |
| 39–51 | Two pan shakes: push (`in`) and pull (`out`), the body bobbing with it. | |
| 55 | **Toss the pan**: arms rise, body back 12°, head tilted up following the food, Hips +3.5 cm. | `snap` |
| 61 | **Catch**: crouch 3.5 cm. | `in` |
| 66 | Back to the center with a bounce. | `out` |
| 72 | = frame 0. | |

**Tony:** tempo 1.1, amplitude ×1.1.

### 3.4 `victory` — play once, 2.0 s (60 f), hold at the end

**Apis** (a joyful jump):

| Frame | Pose | Easing |
|---|---|---|
| 0 | Neutral. | |
| 7 | **Wind-up**: crouch 9 cm, body leaning 22°, both arms pulled far back. | |
| 13 | **Jump**: Hips +20 cm, legs bent in the air, both arms in a high V, head tilted up. | `snap` |
| 19 | Coming down, legs begin to straighten. | |
| 22 | **Landing**: squash, crouch 7 cm, arms open. | `in` |
| 28–43 | Two fist pumps: the right fist rises (`out`), lowers with the body crouching (`in`). The left fist on the hip. | |
| 50 | **Final pose**: right fist angled upward, chest out, head tilted up. Hold until 60. | `out` |

**Tony** (arrogant): a small wind-up, a small 9 cm jump (`snap`), a landing, then a **belly laugh**: body leaning back, left hand on the hip, right hand on the belly, body shaking 4× (frames 22–44). Frame 49: **pointing** at the opponent diagonally forward-sideways with overshoot (`out`), hold.

### 3.5 `lose` — play once, 2.4 s (72 f), hold at the end

The same start for both: at frame 5 a **startle** (`snap`): hopping back 3.5 cm and up 4 cm, both hands to the face, shoulders up, the head jerked back. Frames 8–17: trembling left-right.

**Apis** (disappointed):

| Frame | Pose | Easing |
|---|---|---|
| 30 | Deflate: shoulders drop, arms fall. | |
| 40 | **Collapse**: crouch 11 cm, body leaning, arms hanging forward. | `in` |
| 45 | A slight bounce. | `out` |
| 55 | Inhale: shoulders rise, head rises a little. | |
| 66 | **A sigh**: shoulders drop, head lowered and tilted. Hold. The face stays visible from the front. | `in` |

**Tony** (drama): frame 22 holds his head (`out`), 27–37 shakes his head 3× in disbelief, frame 43 **drops to his knees** (`in`, bouncing at 47), frames 52–63 pound the floor 2× with both fists (`in`/`out`), then slump. Hold.

## 4. Style parameters per character

| Parameter | Apis | Tony |
|---|---|---|
| Tempo multiplier `idle` / `chop` / `busy` | 1.0 / 1.0 / 1.0 | 1.2 / 0.85 / 1.1 |
| Amplitude multiplier (`idle` / `chop` / `busy`) | 1.0 | 1.3 / 1.15 / 1.1 (`victory`, `lose` have Tony's own poses) |
| Base posture (Spine) | leaning +4° | hunched +8°, belly forward |
| Hips height (from rest) | 0.248 m | 0.213 m → all Hips offsets are multiplied by 0.86 |
| Special poses | — | hand on hip (`idle`, `victory`), hand on head (`lose`) |

Technical note: both rigs have the same bone names, but the rest orientation differs slightly. Poses are written as rotations
**relative to rest** in each bone's local space, then re-checked on Tony. If a bone points the wrong way, correct it
in Tony's special pose table.

## 5. Blender → Godot pipeline

1. Import `apis.glb` and `tony.glb` into Blender (one working file `art/blender/chefs_anim.blend`), each in its own collection.
2. Check the rest pose and bone axes (arms, head, Spine, Hips) with a test pose.
3. The pose script builds 5 **Actions** per armature (`idle`, `chop`, `busy`, `victory`, `lose`), then pushes them to the NLA.
4. A check render: a contact sheet of several frames per clip from the front.
5. Export glTF Binary: +Y up, mesh + skin + material + textures kept, animation in **Actions** mode, no cameras/lights.
   Overwrite `godot/assets/characters/apis.glb` and `tony.glb`.
6. Godot: set the `idle`/`chop`/`busy` loops through `.import` (`_subresources`), check with a headless test
   (the AnimationPlayer holds 5 clips, with correct durations and loops) and render a few frames.

## 6. Out of scope (next stage)

- ~~Attaching the GLB to `scenes/stage/chef.tscn` and calling clips from `chef.gd`~~ ✅ (see §7).
- Extra GDD §7.4 clips: `hit`, `taunt`, `hop`.
- Props (knife, cutting board, pan).
- Stage scale: the GLB stays 1 m tall; scale is set in the scene (Apis 2.3 m, Tony ×0.95 per CHARACTER_PLAN §6.1).

## 7. Results (done)

- ✅ The script `art/blender/chef_anims.py` builds all five clips from the pose table above, one character per Blender session:
  ```
  blender -b --factory-startup --python art/blender/chef_anims.py -- apis [--sheet <png>] [--no-export]
  blender -b --factory-startup --python art/blender/chef_anims.py -- tony
  ```
  Input: `art/blender/src/<name>_src.glb` (the original Tripo + Mixamo GLB, unchanged). Output: `godot/assets/characters/<name>.glb`
  and the working file `art/blender/<name>_anim.blend` (an Action per clip, stored in the NLA). Blender version used: 5.1.
- ✅ Poses are written as ops in rest space (world axes, "swing toward DOWN/FWD/OUT", elbow flex, twist), then converted to
  local bone rotations. Crouching uses a simple two-bone IK so the feet stay planted.
- ✅ Godot: the `idle`/`chop`/`busy` loops are set in `.import` (`_subresources`). `tests/glb_check.gd` (headless) checks
  53 bones, a skinned mesh, 5 clips, and the loop flags. `tests/glb_render.gd` (window) renders each clip at its key moments.
- Adjustments from the plan: Tony's head bow and `busy` turn were reduced, and the `victory` arm poses were angled
  (see the note on each clip). The big chibi head hides motions that go too straight up or forward.
- Durations in Godot are +1 frame (e.g. 2.03 s), because the loop's last frame = the first frame. It is not visible in play.
- **Revision 2** (feedback: too stiff and small): `chop`, `busy`, `victory`, `lose` were rebuilt with bigger poses
  and per-key easing (§3, the Easing table). `idle` is unchanged. `chop` became 3 chops per cycle (1.2 s). The `victory` jump
  is 20 cm with bent legs. Apis's `lose` collapses with the face still visible, Tony pounds the floor.
- Check a sheet without exporting: `-- apis --sheet <png> --no-export --clips chop,busy --cols 12 --view front --size 220`.
- ✅ **Installed in the game.** `stage.tscn`: the models are children `Player/apis` and `Rival/tony` (scale 2.6 and 2.47, raised 0.3 m
  so the working hands are visible above the counter). `Chef.character` picks the model, and Rosa (no model yet) uses a
  placeholder. `main.gd` → `_bind_chefs`: `card_played` → `chop`, `dish_served` → `busy`, `duel_ended` → `victory`/`lose`.
  The procedural bob and hop are only for the placeholder, but the flinch on taking Pressure stays. Test: `tests/chef_drive.gd`.
