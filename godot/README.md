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

Shortcut in-game: **E** = End Turn, **S** = Serve.

## Struktur

```
godot/
  project.godot           Renderer: Compatibility (wajib untuk export Web)
  export_presets.cfg      Preset "Web" → build/web/index.html
  data/                   SEMUA konten, 1 file .tres per item (edit di Inspector)
    cards/ recipes/ enemies/ books/ decks/
  scripts/
    data/                 Class Resource: CardDef, RecipeDef, EffectDef, EnemyDef, IntentDef, BookDef, DeckDef, StatusDefs
    core/                 Logika murni, tanpa node: Duel, RecipeMatch, SeededRng, CardInstance
    game_db.gd            GameDB: load semua .tres di data/ lalu cari by id
    stage/                Stage (3D diorama), Chef
    ui/                   DuelUI (HUD), CardView
    main.gd               Entry point: cookbook → duel
  scenes/
    main.tscn             Stage + DuelUI
    stage/                stage.tscn, chef.tscn, counter.tscn  ← atur posisi/kamera/lampu di editor 3D
    ui/                   duel_ui.tscn, card_view.tscn        ← atur layout HUD di editor 2D
  tests/sim.gd            Test headless (port dari scripts/sim.ts)
```

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

## Belum di-port (masih graybox sederhana)

Versi Godot sudah bisa dimainkan penuh (cookbook → duel → menang/kalah → rematch), tapi HUD-nya
lebih polos dari versi web. Yang belum:

- Drag & drop kartu ke Prep Board (sekarang: klik kartu)
- Ikon status/tag dan highlight keyword + tooltip kaya di teks kartu
- Intent pill yang menempel di atas kepala rival (`Stage.screen_pos(rival_intent_anchor)` sudah siap)
- Angka damage melayang, cut-in Signature Dish
- Toggle filter pixel (bisa pakai `SubViewport` resolusi rendah + `TEXTURE_FILTER_NEAREST`)
