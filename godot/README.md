# FINALE — versi Godot 4.7

Port dari versi Vite + TypeScript + Three.js (`../src`). Logika duel sudah 1:1 (test `sim` lulus semua,
statistik bot sama dengan versi TS). Versi web lama tetap ada sebagai referensi sampai versi Godot
setara, lalu boleh dihapus.

## Buka project

1. Jalankan Godot 4.7.2 (`H:\Godot_v4.7.2-stable_win64.exe`).
2. Project Manager → **Import** → pilih `godot/project.godot`.
3. Tekan **F5**. Main scene: `scenes/main.tscn`.

Setup duel (pengganti URL param lama) ada di Inspector node **Main**:

| Dulu (web) | Sekarang (Inspector `Main`) |
|---|---|
| `?enemy=rosa` | `Enemy Id` |
| `?deck=dev` | `Dev Deck` |
| `?hype=100` | `Start Hype` |

**Cara main:** kartu di-**drag**. Bahan → seret ke salah satu dari **3 Station**. Teknik → seret ke atas
keluar dari tangan lalu lepas. Klik biasa pada kartu hanya memunculkan hint "Drag a card to play it".

**Station Stack** (lihat `../ART_DIRECTION.md` §6):
- Bahan menumpuk ke bawah seperti solitaire. Kartu lama hanya terlihat pita nama + ikon tag, kartu terbaru terbuka penuh (bingkai emas).
- Order Ticket di atas tiap station memberi hint resep dan langkah berikutnya. Urutan pas dari kartu pertama = **Perfect** ×1.5,
  bahan lengkap tapi urutan beda = **Cooked** ×1, bahan setelah resep lengkap = **Garnish**, tidak cocok = Improvised.
- Tiap station punya tombol **Serve** (1 Heat, sekali per giliran) dan **Clear**.
- Kartu teratas bisa di-drag ke station lain, **sekali per giliran** (Clear juga memakai jatah ini).

Alur match: 3 · 2 · 1 → ROUND N / FIGHT! di awal, FINISHED → YOU WINS! atau LOSER di akhir (`scripts/ui/announcer.gd`).
Lawan memunculkan emote di samping kepala (`scripts/ui/emote_bubble.gd`): Smug saat Confidence-mu ≤30%,
Shocked saat kena ≥15, Angry saat lawan ≤25%, Sad saat lawan kalah, Confident saat intent ≥10.

Shortcut in-game: **E** = End Turn, **tahan klik / Space** saat giliran rival = percepat ×3, **S** = Serve station terbaik, **P** = filter pixel, **F11** = fullscreen.

Resolusi desain 1920x1080 (stretch `canvas_items` + `expand`), tapi window dibuka **1600x900**
(`window_*_override`) supaya window + title bar muat di layar 1080p. UI mengikuti ukuran window
apa pun; `tests/hit_probe.gd` memastikan tiap tombol bisa diklik penuh setelah resize.

> Kalau menjalankan dari editor dan tidak bisa klik apa pun: di tab **Game** editor, pastikan mode
> input aktif (bukan mode *Select* 2D/3D), atau matikan *Embed Game* supaya game jalan di window sendiri.
>
> Kalau klik **meleset** (harus klik sedikit di bawah tombol): window Game floating lebih besar dari
> layar, lalu Windows menggesernya sementara game yang di-embed tidak ikut. Kecilkan window Game itu
> supaya muat di layar, atau pakai **F11** untuk fullscreen. Jangan menarik window melebihi layar.

## Struktur

```
godot/
  project.godot           Renderer: Compatibility (wajib untuk export Web)
  export_presets.cfg      Preset "Web" → build/web/index.html
  data/                   SEMUA konten, 1 file .tres per item (edit di Inspector)
    cards/ recipes/ enemies/ books/ decks/
  assets/icons/           Ikon SVG putih (dari src/ui/icons.ts), diwarnai lewat self_modulate
  assets/ui_theme.tres    Theme project: font + warna teks default
  scripts/
    data/                 Class Resource: CardDef, RecipeDef, EffectDef, EnemyDef, IntentDef, BookDef, DeckDef, StatusDefs
    core/                 Logika murni, tanpa node: Duel, RecipeMatch, SeededRng, CardInstance
    game_db.gd            GameDB: load semua .tres di data/ lalu cari by id
    stage/                Stage (3D diorama), Chef
    ui/                   DuelUI (HUD + drag), CardView, Ui (builder panel/ikon), Pal (palet warna), Keywords
    ui/hud/               HudPanel (panel + tab), HpBar, SegBar, DiamondBadge: widget HUD v2 yang dipasang di .tscn
    main.gd               Entry point: cookbook → duel
  scenes/
    main.tscn             Stage + DuelUI
    stage/                stage.tscn, chef.tscn, counter.tscn  ← atur posisi/kamera/lampu di editor 3D
    ui/                   duel_ui.tscn, card_view.tscn        ← atur layout HUD di editor 2D
  tests/sim.gd            Test headless logika (port dari scripts/sim.ts)
  tests/ui_drive.gd       Test UI dengan input mouse simulasi + screenshot
  tests/hit_probe.gd      Cek area klik semua tombol di beberapa ukuran window
  tests/balance.gd        Balancing: ratusan duel bot vs rival, win rate + panjang duel (-- sweep)
  tests/glb_check.gd      Headless: model karakter (apis/tony.glb) berisi 5 clip + flag loop
  tests/chef_drive.gd     Window: clip chef mengikuti event duel di game sungguhan + screenshot
```

### Karakter 3D

Model ada di `assets/characters/` (dibuat lewat `../art/blender/chef_anims.py`, lihat `../ANIMATION_DESIGN.md`).
Di `stage.tscn`, tiap chef (`Player`, `Rival`) punya child model bernama id karakter (`apis`, `tony`);
`Chef.character` memilih yang tampil, dan tanpa model yang cocok (mis. Rosa) placeholder kapsul yang muncul.
Skala dan tinggi model diatur di transform child itu. Clip mengikuti event duel (`main.gd` → `_bind_chefs`):
kartu dimainkan → `chop`, dish disajikan → `busy`, duel selesai → `victory` / `lose` (ditahan sampai duel berikutnya).

### Peta TS → Godot

| TypeScript | Godot |
|---|---|
| `core/types.ts` | `scripts/data/*_def.gd` (Resource, bisa diedit di Inspector) |
| `data/cards.ts`, `recipes.ts`, `enemies.ts` | `data/**/*.tres` |
| `data/statuses.ts` | `scripts/data/status_defs.gd` |
| `core/duel.ts` | `scripts/core/duel.gd` (class `Duel`) |
| `core/events.ts` (EventBus) | **signal** bawaan Godot di `Duel` (`duel.changed.connect(...)`) |
| `core/recipes.ts` | `scripts/core/recipe_match.gd` |
| `core/rng.ts` | `scripts/core/seeded_rng.gd` (mulberry32, bit-exact dengan TS) |
| `render3d/stage.ts` | `scenes/stage/stage.tscn` + `scripts/stage/stage.gd` |
| `ui/hud.ts` | `scenes/ui/duel_ui.tscn` + `scripts/ui/duel_ui.gd` |
| `scripts/sim.ts` | `tests/sim.gd` |

Prinsip GDD §9 tetap: **data-driven**, **effect composable**, **logika terpisah dari visual**
(`Duel` adalah `RefCounted` tanpa node; visual hanya mendengarkan signal).

## Menambah / mengubah konten

- **Kartu baru:** FileSystem → klik kanan `data/cards/` → *New Resource…* → `CardDef`. Isi `id`
  (unik), `name`, `cost`, `tags`, `quality`, `effects`. Tidak perlu kode.
- **Resep:** `RecipeDef`. `requires` berurutan sesuai Recipe Book (urutan ini = Perfect Order ×1.5).
  Isinya tag (`FAT`) atau kartu kunci (`card:beef`).
- **Rival:** `EnemyDef` dengan `pattern` berisi `IntentDef` (attack `-1` = tidak menyerang,
  status `none` = tanpa status).
- **Deck / buku resep:** `DeckDef` / `BookDef`, seret file `.tres` ke array di Inspector.

`.tres` di `data/` sekarang **sumber kebenaran**. `../scripts/export-godot-data.ts` hanya dipakai
sekali untuk migrasi; menjalankannya lagi akan **menimpa** editan di Godot.

## Test

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/sim.gd
& "H:\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/fx_check.gd
```

Balancing (GRAND_DESIGN §8.2): laporan angka sekarang, atau `-- sweep` untuk mencoba nilai lain
(`hp=`, `tony=`, `rosa=`, `flow=`, `n=`). Angkanya diubah di `.tres` rival dan Inspector `Main` → Balance.

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/balance.gd
```

Animasi chef di game (butuh window):

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --path godot --resolution 1600x900 --script res://tests/chef_drive.gd -- "$env:TEMP"
```

Kalau baru clone (folder `.godot/` belum ada), jalankan sekali dulu:

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --import
```

## Export Web untuk jam

1. Editor → *Editor → Manage Export Templates* → **Download and Install** (4.7.2). Saat ini belum terpasang.
2. *Project → Export* → preset **Web** sudah ada → **Export Project** → `godot/build/web/index.html`.
3. Upload isi `build/web/` (ada `index.html` di root).

Catatan syarat jam (GDD §9):
- Renderer **Compatibility** (WebGL 2) — sudah diset. Jangan ganti ke Forward+.
- **Thread Support mati** di preset, jadi tidak butuh header COOP/COEP (SharedArrayBuffer) dari host.
- Ukuran: engine web Godot ±35–40 MB (wasm, belum gzip). Masih di bawah 50 MB, tapi jaga ukuran aset.
- Cek "Frame pertama < 10 detik" setelah export, di host jam.
- Sinyal `og:ready`: panggil lewat `JavaScriptBridge.eval(...)` setelah duel pertama tampil
  (API SDK OpenGame belum diintegrasikan, sama seperti versi web).

## Status port UI

HUD v2 (board "HUD v2" di canvas, lihat ART_DIRECTION §4): panel gelap bertab yang tetap di layar.
Top bar ROUND + Hype bersegmen, panel rival kanan atas (diamond intent, nama, bar Confidence dengan
cap Composure biru, status), panel STATIONS kiri atas (tiket bergerigi, stack solitaire, SERVE/Clear),
panel PLAYER kiri bawah (diamond potret, bar Confidence, pip Heat), pile draw/discard, kartu gelap
bergaya "Kartu v2" (blok biaya teal, banner nama, jendela art per tipe, bar Quality, tooltip keyword),
drag & drop dengan ghost miring, zona "Release to play", angka melayang, banner dish, cut-in Signature
Dish, Recipe Book v2 (satu resep per halaman, urutan masak, pita bab), layar Victory/Defeat, tooltip di semua elemen, filter pixel (tombol kanan atas / P).

Perbedaan kecil yang tersisa:
- Font: pakai SystemFont "Trebuchet MS" (Windows). Di build **Web**, SystemFont tidak tersedia dan jatuh
  ke font bawaan Godot. Untuk jam, tambahkan file font OFL (mis. Nunito Black) ke `assets/` dan pasang di
  `assets/ui_theme.tres`.
- Gradien halus CSS (kartu, zona play) diganti warna rata.
- Intent pill tidak "bob" naik-turun.
- Pencahayaan 3D dikalibrasi manual: di renderer Compatibility, matahari ber-bayangan dirender sebagai
  pass terpisah yang dijumlahkan setelah konversi sRGB, jadi energinya sengaja kecil (sun 0.35, ambient 0.15).

Test UI (butuh window, bukan headless):

```powershell
& "H:\Godot_v4.7.2-stable_win64_console.exe" --path godot --resolution 1920x1080 --script res://tests/ui_drive.gd -- "$env:TEMP"
& "H:\Godot_v4.7.2-stable_win64_console.exe" --path godot --resolution 1366x768 --script res://tests/hit_probe.gd
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

Beberapa cue di frame yang sama tidak menumpuk: nilai terkuat per field yang dipakai.
Test: `tests/fx_check.gd` (headless) memeriksa anggaran tiap tier, pemetaan signal, hitstop, shake, overlay, batas partikel
(≤ 150 hidup), satu kata per frame, retak, punch zoom, crowd, dan angka slam.

## Audio

Autoload **`Audio`** (`scripts/audio/audio.gd`) mendengarkan signal `Duel`; logika duel tidak tahu soal audio.
Bus: `Music` (-6 dB) dan `SFX` di `default_bus_layout.tres`. Test: `tests/audio_check.gd` (headless).

| Kondisi | File |
|---|---|
| Layar Recipe Book sebelum duel | `music/Building_Deck_Theme.mp3` (loop) |
| Duel biasa (rival tanpa `boss`) | `music/Battle_Theme.mp3` (loop) + `sfx/Round start` |
| Duel boss / grand final (`EnemyDef.boss = true`) | `sfx/Boss appearance sting`, Battle_Theme **tidak** diputar |
| Menang | `sfx/Round won` + `music/Clear_Victory.mp3` |
| Kalah | `music/Game_Over_Smile.mp3` |
| Giliran baru | `sfx/Turn change` |
| Bahan ditaruh di Station | `sfx/Prep Board chopping` |
| Kartu teknik dimainkan | `sfx/Pan sizzle` |
| Kartu Signature Dish dimainkan | `sfx/Signature Dish activation` |
| Serve | `sfx/Ingredient added to a pot` lalu `sfx/Cooking bell ding` |
| Status Burnt / Spicy | `sfx/Burn status applied` / `sfx/Poison status applied` |
| Status lain | `sfx/Debuff applied` / `sfx/Buff applied` |

Belum terpakai karena fiturnya belum ada: `Main_Menu` (belum ada main menu), `Stun or freeze`
(belum ada status stun), `Timer running out warning` (belum ada timer). Key-nya sudah terdaftar,
tinggal panggil `Audio.play_music("menu")` / `Audio.sfx("stun")` / `Audio.sfx("timer")`.
