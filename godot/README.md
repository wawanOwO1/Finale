# FINALE — Godot 4.7 version

A port of the Vite + TypeScript + Three.js version (`../src`). The duel logic is already 1:1 (all `sim` tests pass,
bot statistics match the TS version). The old web version stays as a reference until the Godot version is
equivalent, then it may be deleted.

## Open the project

1. Launch Godot 4.7.2 (`H:\Godot_v4.7.2-stable_win64.exe`).
2. Project Manager → **Import** → choose `godot/project.godot`.
3. Press **F5**. Main scene: `scenes/main.tscn`.

The duel setup (replacing the old URL params) is in the **Main** node's Inspector:

| Before (web) | Now (`Main` Inspector) |
|---|---|
| `?enemy=rosa` | `Enemy Id` |
| `?deck=dev` | `Dev Deck` |
| `?hype=100` | `Start Hype` |

**How to play:** cards are **dragged**. Ingredient → drag onto one of the **3 Stations**. Technique → drag up
out of the hand and release. A plain click on a card only shows the hint "Drag a card to play it".

**Station Stack** (see `../ART_DIRECTION.md` §6):
- Ingredients stack downward like solitaire. Older cards show only a name ribbon + tag icon, the newest card is fully visible (gold frame).
- The Order Ticket above each station hints at the recipe and the next step. An exact order from the first card = **Perfect** ×1.5,
  all ingredients but a different order = **Cooked** ×1, ingredients after the recipe is complete = **Garnish**, no match = Improvised.
- Each station has a **Serve** button (1 Heat, once per turn) and a **Clear** button.
- The top card can be dragged to another station, **once per turn** (Clear also uses this allowance).

Match flow: 3 · 2 · 1 → ROUND N / FIGHT! at the start, FINISHED → YOU WINS! or LOSER at the end (`scripts/ui/announcer.gd`).
The opponent shows an emote beside their head (`scripts/ui/emote_bubble.gd`): Smug when your Confidence is ≤30%,
Shocked when hit for ≥15, Angry when the opponent is ≤25%, Sad when the opponent loses, Confident when an intent is ≥10.

In-game shortcuts: **E** = End Turn, **hold click / Space** during the rival's turn = ×3 speed, **S** = Serve the best station, **P** = pixel filter, **F11** = fullscreen.

The design resolution is 1920x1080 (`canvas_items` stretch + `expand`), but the window opens at **1600x900**
(`window_*_override`) so the window + title bar fit on a 1080p screen. The UI follows any window size;
`tests/hit_probe.gd` makes sure every button is fully clickable after a resize.

> If you run from the editor and cannot click anything: in the editor's **Game** tab, make sure input mode
> is active (not *Select* 2D/3D mode), or turn off *Embed Game* so the game runs in its own window.
>
> If clicks **miss** (you have to click slightly below the button): the floating Game window is bigger than the
> screen, and Windows shifts it while the embedded game does not follow. Shrink that Game window
> to fit the screen, or use **F11** for fullscreen. Do not drag the window past the screen.

## Structure

```
godot/
  project.godot           Renderer: Compatibility (required for Web export)
  export_presets.cfg      "Web" preset → build/web/index.html
  data/                   ALL content, 1 .tres file per item (edit in the Inspector)
    cards/ recipes/ enemies/ books/ decks/
  assets/icons/           White SVG icons (from src/ui/icons.ts), colored via self_modulate
  assets/ui_theme.tres    Project theme: font + default text color
  scripts/
    data/                 Resource classes: CardDef, RecipeDef, EffectDef, EnemyDef, IntentDef, BookDef, DeckDef, StatusDefs
    core/                 Pure logic, no nodes: Duel, RecipeMatch, SeededRng, CardInstance
    game_db.gd            GameDB: loads every .tres in data/ then looks up by id
    stage/                Stage (3D diorama), Chef
    ui/                   DuelUI (HUD + drag), CardView, Ui (panel/icon builder), Pal (color palette), Keywords
    ui/hud/               HudPanel (panel + tab), HpBar, SegBar, DiamondBadge: HUD v2 widgets placed in the .tscn
    main.gd               Entry point: cookbook → duel
  scenes/
    main.tscn             Stage + DuelUI
    stage/                stage.tscn, chef.tscn, counter.tscn  ← set position/camera/lights in the 3D editor
    ui/                   duel_ui.tscn, card_view.tscn        ← set the HUD layout in the 2D editor
  tests/sim.gd            Headless logic test (port of scripts/sim.ts)
  tests/ui_drive.gd       UI test with simulated mouse input + screenshots
  tests/hit_probe.gd      Checks every button's click area at several window sizes
  tests/balance.gd        Balancing: hundreds of bot vs rival duels, win rate + duel length (-- sweep)
  tests/glb_check.gd      Headless: character models (apis/tony.glb) contain 5 clips + loop flags
  tests/chef_drive.gd     Window: chef clips follow duel events in the real game + screenshots
```

### 3D characters

Models are in `assets/characters/` (made with `../art/blender/chef_anims.py`, see `../ANIMATION_DESIGN.md`).
In `stage.tscn`, each chef (`Player`, `Rival`) has child models named after the character id (`apis`, `tony`);
`Chef.character` chooses which one shows, and without a matching model (e.g. Rosa) a capsule placeholder appears.
The model's scale and height are set in that child's transform. Clips follow duel events (`main.gd` → `_bind_chefs`):
card played → `chop`, dish served → `busy`, duel finished → `victory` / `lose` (held until the next duel).

### TS → Godot map

| TypeScript | Godot |
|---|---|
| `core/types.ts` | `scripts/data/*_def.gd` (Resource, editable in the Inspector) |
| `data/cards.ts`, `recipes.ts`, `enemies.ts` | `data/**/*.tres` |
| `data/statuses.ts` | `scripts/data/status_defs.gd` |
| `core/duel.ts` | `scripts/core/duel.gd` (class `Duel`) |
| `core/events.ts` (EventBus) | Godot's built-in **signals** on `Duel` (`duel.changed.connect(...)`) |
| `core/recipes.ts` | `scripts/core/recipe_match.gd` |
| `core/rng.ts` | `scripts/core/seeded_rng.gd` (mulberry32, bit-exact with TS) |
| `render3d/stage.ts` | `scenes/stage/stage.tscn` + `scripts/stage/stage.gd` |
| `ui/hud.ts` | `scenes/ui/duel_ui.tscn` + `scripts/ui/duel_ui.gd` |
| `scripts/sim.ts` | `tests/sim.gd` |

The GDD §9 principles still hold: **data-driven**, **composable effects**, **logic separated from visuals**
(`Duel` is a `RefCounted` with no nodes; visuals only listen to signals).

## Adding / changing content

- **New card:** FileSystem → right-click `data/cards/` → *New Resource…* → `CardDef`. Fill in `id`
  (unique), `name`, `cost`, `tags`, `quality`, `effects`. No code needed.
- **Recipe:** `RecipeDef`. `requires` is ordered to match the Recipe Book (this order = Perfect Order ×1.5).
  It holds tags (`FAT`) or key cards (`card:beef`).
- **Rival:** `EnemyDef` with a `pattern` of `IntentDef` (attack `-1` = does not attack,
  status `none` = no status).
- **Deck / recipe book:** `DeckDef` / `BookDef`, drag `.tres` files into the arrays in the Inspector.

The `.tres` files in `data/` are now the **source of truth**. `../scripts/export-godot-data.ts` was only used
once for the migration; running it again will **overwrite** edits made in Godot.

## Tests

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/sim.gd
& "H:\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/fx_check.gd
```

Balancing (GRAND_DESIGN §8.2): prints the current numbers, or `-- sweep` to try other values
(`hp=`, `tony=`, `rosa=`, `flow=`, `n=`). The numbers are changed in the rival `.tres` files and in `Main` Inspector → Balance.

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/balance.gd
```

Chef animations in the game (needs a window):

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --path godot --resolution 1600x900 --script res://tests/chef_drive.gd -- "$env:TEMP"
```

If you just cloned (the `.godot/` folder does not exist yet), run this once first:

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --import
```

## Web export for the jam

1. Editor → *Editor → Manage Export Templates* → **Download and Install** (4.7.2). Not installed yet.
2. *Project → Export* → the **Web** preset already exists → **Export Project** → `godot/build/web/index.html`.
3. Upload the contents of `build/web/` (with `index.html` at the root).

Jam requirement notes (GDD §9):
- **Compatibility** renderer (WebGL 2) — already set. Do not switch to Forward+.
- **Thread Support is off** in the preset, so no COOP/COEP headers (SharedArrayBuffer) are needed from the host.
- Size: the Godot web engine is ±35–40 MB (wasm, not gzipped). Still under 50 MB, but watch the asset size.
- Check "First frame < 10 seconds" after exporting, on the jam host.
- The `og:ready` signal: call it through `JavaScriptBridge.eval(...)` after the first duel is shown
  (the OpenGame SDK API is not integrated yet, same as the web version).

## UI port status

HUD v2 (the "HUD v2" board on the canvas, see ART_DIRECTION §4): dark tabbed panels that stay on screen.
Top bar ROUND + segmented Hype, rival panel at the top right (intent diamond, name, Confidence bar with a
blue Composure cap, statuses), STATIONS panel at the top left (jagged ticket, solitaire stack, SERVE/Clear),
PLAYER panel at the bottom left (portrait diamond, Confidence bar, Heat pips), draw/discard piles, dark cards
in the "Card v2" style (teal cost block, name banner, per-type art window, Quality bar, keyword tooltips),
drag & drop with a slanted ghost, a "Release to play" zone, floating numbers, a dish banner, the Signature
Dish cut-in, Recipe Book v2 (one recipe per page, cooking order, chapter ribbons), Victory/Defeat screens, tooltips on every element, a pixel filter (top-right button / P).

Small remaining differences:
- Font: uses the SystemFont "Trebuchet MS" (Windows). In the **Web** build, SystemFont is unavailable and falls
  back to Godot's built-in font. For the jam, add an OFL font file (e.g. Nunito Black) to `assets/` and set it in
  `assets/ui_theme.tres`.
- CSS soft gradients (cards, play zone) were replaced with flat colors.
- The intent pill does not "bob" up and down.
- The 3D lighting is calibrated by hand: in the Compatibility renderer, the shadow-casting sun is rendered as a separate
  pass that is added after the sRGB conversion, so its energy is deliberately small (sun 0.35, ambient 0.15).

UI tests (need a window, not headless):

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --path godot --resolution 1920x1080 --script res://tests/ui_drive.gd -- "$env:TEMP"
& "H:\Godot_v4.7.2-stable_win64_console.exe" --path godot --resolution 1366x768 --script res://tests/hit_probe.gd
& "H:\Godot_v4.7.2-stable_win64_console.exe" --path godot --resolution 1600x900 --script res://tests/fx_drive.gd
```

## FX (hitstop, shake, flash)

Node **`FxDirector`** di `main.tscn` (`scripts/fx/`, lihat `../FX_MASTERPLAN.md`) mendengarkan signal `Duel`.
Rasa tiap momen = satu `FxCue` di `data/fx/*.tres` (hitstop, trauma shake, flash, desaturasi, punch zoom, partikel,
kata manga, crowd melompat, retak bar Confidence), diatur di Inspector.
Anak node: **`HitStop`** (satu-satunya yang menulis `Engine.time_scale`; TurnDirector hanya mengisi `fast_forward`)
dan **`Shake`** (offset kamera stage + offset CanvasLayer HUD, dibulatkan ke grid 3 px).
Flash/desaturasi lewat `%FxScreen` di `duel_ui.tscn` (`assets/shaders/fx_screen.gdshader`), tersembunyi saat tidak dipakai.
Partikel dan kata manga lewat `%FxHud` (`scripts/fx/fx_hud.gd`): 2 `CPUParticles2D` per jenis (`Crumbs`, `Steam`, `Sparks`,
`Smoke`, `Shards`, dipakai bergiliran, tanpa tekstur) + label `Word1`/`Word2`. Atur bentuk partikel langsung di node-nya.
Angka Pressure ≥ `DuelUI.slam_number_at` (15) di-*slam* besar, bukan melayang biasa.
**Impact frame** (Signature, menang): 3 frame siluet dua warna tinta/krem di `%FxScreen`, frame ke-2 terbalik. Tiap frame
minimal 1/60 s dan 1 frame tergambar. Dengan *Reduce Flashing* diganti desaturasi singkat. Speed lines / cincin kejut lewat
`%FxLines` (`assets/shaders/fx_lines.gdshader`, prosedural, grid 3 px); chromatic split juga di `%FxScreen`.

| Momen | Cue | Tier | Isi |
|---|---|---|---|
| Bahan ditaruh di station | `place` | T0 | remah warna tag |
| Serve yang kena | `serve` | T1 | uap, "CLANG!", crowd kecil |
| Perfect, atau Serve ≥ `big_pressure` (15) | `serve_big` | T2 | uap + percikan, "BAM!!", speed lines singkat, flash krem, punch zoom, crowd |
| Serve Burnt | `serve_burnt` | T1 | asap, "FSSHH...", desaturasi singkat |
| Kehilangan ≥ 25% Confidence sekali kena | `big_hit` | T2 | serpihan merah + "CRACK!" di bar yang retak, flash merah, chromatic |
| Signature Dish | `signature` | T3 | **impact frame**, speed lines, chromatic, flash emas, percikan + uap, punch zoom, crowd penuh |
| Menang / kalah | `win` / `lose` | T3 | **impact frame** + speed lines + serpihan + retak bar lawan / asap + desaturasi panjang |

**Cutscene Signature Dish** (`SignatureCutscene` di `main.tscn`, `scripts/fx/signature_cutscene.gd`): beat-nya adalah
method key di `AnimationPlayer` anaknya (`long` 2.3 s, `short` 1.0 s); geser key di editor animasi untuk mengatur
tempo. Versi panjang sekali per sesi (`long_once`), lalu versi pendek. Urutan panjang: cut-in + letterbox, dunia
dibekukan (`HitStop.cutscene_factor`) → kamera close-up `CutCamera` bergerak dari `CutMarkers/SigFrom` ke `SigTo`
(atur posisinya di `stage.tscn`), HUD memudar, "SLASH!" ×2 → impact frame, kembali ke kamera duel, semua cue yang
ditahan `FxDirector` (damage, KO) mendarat bersamaan → letterbox keluar. Klik / Space / Esc = lompat ke impact.
Cut-in, letterbox, dan semua overlay FX ada di `%FxLayer` (CanvasLayer di atas HUD) supaya HUD bisa memudar sendiri.

**Cutscene Finish** (`FinishCutscene` di `main.tscn`, animasi `win` 1.5 s / `lose` 1.8 s): main sebelum announcer
FINISHED. Menang: impact frame KO, slow-mo ×0.3, kamera meluncur dari pandangan duel ke `CutMarkers/KoWin` (rival),
penonton bersorak. Kalah: slow-mo ×0.5, layar pudar, kamera turun ke `KoLose` (Apis), penonton diam. Kalau
Signature yang menamatkan duel, Finish mulai tepat di impact Signature. Klik untuk skip. Kedua cutscene memakai
base class `FxCutscene` (`scripts/fx/fx_cutscene.gd`).

**Layar VS** (`%VsIntro` di `duel_ui.tscn`, `scripts/fx/vs_intro.gd`): ±2 s sebelum 3·2·1, layar dibagi diagonal,
potret 2D dari `assets/portraits/<id>.png`. Potret dirender sekali dari GLB dengan
`tests/portrait_render.gd` (butuh window; jalankan lagi kalau model berubah). Rival tanpa potret hanya tampil namanya.
Klik untuk skip.

**Debug & kualitas:** **F3** = overlay (FPS, frame time, draw call, partikel, status FX). **Shift+F3** = FX Quality
Low (partikel ×0.5, tanpa chromatic, Signature selalu versi pendek). Di build Web, `FxDirector` pindah ke Low sendiri
kalau FPS rata-rata < 45 selama 3 s (`auto_quality`, hanya di Web). Penonton digambar sebagai satu MultiMesh.
Test `tests/fx_drive.gd` (butuh window): semua cue + cutscene sekali, gagal kalau ada lonjakan frame > 4× median
(shader yang baru dikompilasi saat dipakai pertama kali).

**Export Web:** `project.godot` mematikan `editor/export/convert_text_resources_to_binary`. Konversi teks→biner
di Godot 4.7.2 menghapus `RecipeDef.requires` (PackedStringArray), sehingga di build Web semua resep tidak butuh bahan.

Beberapa cue di frame yang sama tidak menumpuk: nilai terkuat per field yang dipakai.
Test: `tests/fx_check.gd` (headless) memeriksa anggaran tiap tier, pemetaan signal, hitstop, shake, overlay, batas partikel
(≤ 150 hidup), satu kata per frame, retak, punch zoom, crowd, dan angka slam.

## Audio

The **`Audio`** autoload (`scripts/audio/audio.gd`) listens to `Duel` signals; the duel logic knows nothing about audio.
Buses: `Music` (-6 dB) and `SFX` in `default_bus_layout.tres`. Test: `tests/audio_check.gd` (headless).

| Condition | File |
|---|---|
| Recipe Book screen before a duel | `music/Building_Deck_Theme.mp3` (loop) |
| A normal duel (rival without `boss`) | `music/Battle_Theme.mp3` (loop) + `sfx/Round start` |
| Boss / grand final duel (`EnemyDef.boss = true`) | `sfx/Boss appearance sting`, Battle_Theme is **not** played |
| Win | `sfx/Round won` + `music/Clear_Victory.mp3` |
| Lose | `music/Game_Over_Smile.mp3` |
| New turn | `sfx/Turn change` |
| Ingredient placed on a Station | `sfx/Prep Board chopping` |
| Technique card played | `sfx/Pan sizzle` |
| Signature Dish card played | `sfx/Signature Dish activation` |
| Serve | `sfx/Ingredient added to a pot` then `sfx/Cooking bell ding` |
| Burnt / Spicy status | `sfx/Burn status applied` / `sfx/Poison status applied` |
| Other statuses | `sfx/Debuff applied` / `sfx/Buff applied` |

Not used yet because the features do not exist: `Main_Menu` (no main menu yet), `Stun or freeze`
(no stun status yet), `Timer running out warning` (no timer yet). The keys are already registered,
just call `Audio.play_music("menu")` / `Audio.sfx("stun")` / `Audio.sfx("timer")`.
