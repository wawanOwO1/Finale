# MODIFIERS — Daftar & Aturan Chef's Flow Modifier

Dokumen referensi semua **modifier** di FINALE. Sumber kebenaran angka ada di `godot/data/modifiers/*.tres`
(bisa diubah di Inspector); efeknya dikodekan per `id` di `godot/scripts/core/duel.gd`.
Rancangan awal ada di `GRAND_DESIGN.md` §5. Teks di dalam game memakai bahasa Inggris.

---

## 1. Apa itu modifier

- Power-up **sementara per duel**, bukan permanen antar duel. Modifier dan Chef's Flow di-reset tiap duel baru
  (Kitchen dibuat baru tiap duel). Yang permanen sepanjang run adalah Kitchen Tool (GDD §6.4), bukan modifier.
- Didapat dari **Chef's Flow**: tiap Serve **Perfect Order** = +1 Flow. Serve Cooked atau Improvised = +0.
- Saat Flow mencapai threshold, Flow kembali ke 0 dan muncul **pilih 1 dari 3 modifier**.
- Pemain dan rival sama-sama bisa mendapat modifier. Rival memilih otomatis lewat `RivalAI.pick_modifier`.
- Modifier tidak ada RNG di efeknya: damage, Quality, dan buff selalu pasti. RNG hanya ada di **penawaran**
  (stream `offers` / `offers_enemy`, ikut seed duel, jadi bisa direproduksi).

### Threshold Flow

| Pihak | Threshold (Serve Perfect per modifier) | Tempat mengubah |
|---|---|---|
| Pemain (Apis) | **1 → 2 → 3**, lalu tetap 3 | `Duel.PLAYER_FLOW`, Inspector `Main` → Balance |
| Rival (default) | **3 → 4 → 5**, lalu tetap 5 | `EnemyDef.flow_thresholds` (`data/enemies/*.tres`) |

Threshold awal desain adalah 2 → 3 → 4. Fase G (balancing) menurunkannya jadi 1 → 2 → 3 karena Flow hampir tidak
pernah aktif (GRAND_DESIGN §8.2). Rival yang sudah ada (Tony, Rosa) memakai default. Marco, Élodie, dan Bruno belum
ada di data, jadi threshold di GRAND_DESIGN §5.4 baru berlaku saat mereka dibuat.

---

## 2. Daftar modifier (10)

Teks kartu memakai `X` sebagai pengganti angka. Angka `X` = `amount` × jumlah stack.

### Common (7)

| Modifier | id | Teks di game | Amount | Stack | Tag build |
|---|---|---|---|---|---|
| **Hot Pan** | `hot_pan` | Every Serve deals +X Pressure. | 3 | Ya (+3 / stack) | — |
| **Steady Hands** | `steady_hands` | +X Composure each time you place an ingredient. | 1 | Ya (+1 / stack) | — |
| **Encore** | `encore` | Perfect Order multiplier +X. | 0.25 | Ya (+0.25 / stack) | — |
| **Extra Burner** | `extra_burner` | After a Perfect Order Serve, +X Heat next turn. | 1 | Tidak | — |
| **Prep Cook** | `prep_cook` | Draw +X card at the start of each turn. | 1 | Tidak | — |
| **Crowd Favorite** | `crowd_favorite` | +X Hype on every Serve. | 10 | Ya (+10 / stack) | — |
| **Spice Whisperer** | `spice_whisperer` | Placing a SPICE ingredient gives the rival Spicy X. | 1 | Ya (+1 / stack) | `SPICE` |

### Rare (3)

| Modifier | id | Teks di game | Amount | Stack | Tag build |
|---|---|---|---|---|---|
| **Free Move** | `free_move` | Move a top card up to X times per turn. | 2 | Tidak | — |
| **Mise Master** | `mise_master` | Mise en Place also helps when your hand has only 1 ingredient. | 1 | Tidak | — |
| **Plating Pro** | `plating_pro` | Garnish gives xX Quality. | 2 | Tidak | — |

Ikon: Hot Pan `heat`, Steady Hands `composure`, Encore `check`, Extra Burner `heat`, Prep Cook `draw`,
Crowd Favorite `hype`, Spice Whisperer `spicy`, Free Move `arrow`, Mise Master `inspired`, Plating Pro `crown`.

---

## 3. Cara kerja tiap modifier

| Modifier | Kapan aktif | Efek persis | Kode |
|---|---|---|---|
| **Hot Pan** | Setiap Serve, sesudah dish diresolusi | Menambah Pressure flat ke lawan: `3 × stack`. Berlaku di **setiap** Serve (di desain awal "Serve pertama tiap giliran"; sama saja karena Serve hanya sekali per giliran). Tidak jalan kalau duel sudah selesai. | `Duel.serve_bonus`, `serve()` |
| **Steady Hands** | Tiap menaruh bahan di station | +`1 × stack` Composure. Teknik tidak memicunya. | `play_card` |
| **Encore** | Menghitung multiplier Serve | Multiplier Perfect Order jadi `1.5 + 0.25 × stack` (stack 1 = ×1.75, stack 2 = ×2.0). | `Duel.perfect_mult` |
| **Extra Burner** | Serve Perfect, dipakai di awal giliran berikutnya | Heat giliran berikutnya +1 di atas maksimum. Hanya satu kali pakai per pemicu, tidak menumpuk. | `serve()`, `_start_turn` |
| **Prep Cook** | Awal tiap giliran | Draw +1 kartu di atas ukuran tangan normal. | `_start_turn` |
| **Crowd Favorite** | Setiap Serve | +`10 × stack` Hype, ditambah Hype dari resep. Mempercepat Signature Dish. | `serve()` |
| **Spice Whisperer** | Tiap menaruh bahan ber-tag `SPICE` | Lawan mendapat status Spicy `1 × stack`. Hanya ditawarkan ke deck yang punya build `SPICE`. | `play_card` |
| **Free Move** | Aksi pindah kartu teratas | Jatah pindah per giliran jadi 2 (bukan 1). | `Duel._move_left` |
| **Mise Master** | Setelah draw awal giliran | Mise en Place (bad-luck protection) juga aktif kalau tangan punya ≤ 1 bahan yang bisa ditaruh, bukan hanya 0. Tetap maksimal 1× per giliran. | `Duel._mise_en_place` |
| **Plating Pro** | Menghitung Quality dish | Quality dari kartu Garnish (kartu di plate melebihi bahan resep) dikali 2. Di desain awal "Garnish maks +2 → +4", tapi aturan belum punya batas Garnish, jadi diganti ×2. | `Duel.dish_quality` |

---

## 4. Penawaran (pick 1 dari 3)

Dibuat di `Duel._make_offer(side)`:

1. **Komposisi**: 2 slot Common + 1 slot ketiga (Rare 25%, Common 75%).
2. **Pity rarity**: setelah 3 penawaran berturut-turut tanpa Rare (`RARE_PITY`), slot ketiga dijamin Rare.
3. **Tanpa duplikat** dalam satu penawaran.
4. **Non-stackable yang sudah dimiliki** tidak ditawarkan lagi. Yang stackable boleh muncul lagi dan menambah stack.
5. **Cocok build**: build = tag ingredient yang punya ≥ 3 kartu di deck. Modifier ber-tag (saat ini hanya
   Spice Whisperer, tag `SPICE`) hanya muncul kalau deck memakai tag itu. Kalau ada yang cocok, minimal 1 dari 3
   adalah modifier ber-tag tersebut (mengisi slot Common pertama).
6. **Pool menipis**: kalau kandidat kurang dari 3, sisanya diisi dari apa yang tersisa. Kalau kosong total,
   tidak ada penawaran dan Flow tetap di-reset.

Alur UI untuk pemain: overlay `FlowPick` muncul ±1.2 detik setelah Serve (sesudah dish reveal). Selama overlay
terbuka semua aksi ditolak dengan pesan "Pick a modifier first." dan input HUD terkunci.

---

## 5. Rival & modifier

- Rival memilih modifier otomatis. Nilai tiap modifier dihitung `RivalAI.modifier_value` dari bobot profilnya:

| Modifier | Nilai bagi rival |
|---|---|
| Hot Pan | `amount × w_attack` |
| Steady Hands | `amount × 2.5 × w_defend × 2` |
| Encore | `amount × 10 × w_attack` |
| Extra Burner | 2.0 |
| Prep Cook | 2.5 |
| Crowd Favorite | 0.3 (untuk pemain 1.5) |
| Spice Whisperer | `amount × 2 × w_debuff` |
| Free Move | 0.1 (untuk pemain 1.0) |
| Mise Master | 1.5 |
| Plating Pro | `1.5 + ukuran tangan × 0.1` |

- Free Move bernilai rendah bagi rival karena AI belum memakai aksi pindah kartu.
- Saat rival mengambil modifier, Turn Director menampilkan banner (contoh **"TONY GOT / HOT PAN!"**, 1 detik)
  dan ikon masuk ke baris modifier rival di HUD.

---

## 6. Tampilan di HUD

- Baris `PlayerFlow` / `EnemyFlow` di `scenes/ui/duel_ui.tscn`: pip FLOW (●●○) di bawah bar Hype, lalu chip
  modifier berisi ikon, angka stack, dan tooltip (`ModifierDef.describe(stacks)`).
- Ikon diambil dari `res://assets/icons` dan di-tint.
- Overlay pilih modifier (`FlowPick`): 3 pilihan, teksnya dari `ModifierDef.describe()`.

---

## 7. Menambah atau mengubah modifier

**Mengubah angka** (tanpa kode): buka `godot/data/modifiers/<id>.tres` di Inspector, ubah `amount`, `rarity`,
`stackable`, `icon`, `text`, atau `tag`.

**Menambah modifier baru:**
1. Buat `.tres` baru di `godot/data/modifiers/` dengan script `ModifierDef` (salin salah satu yang ada). `id` harus unik.
   `GameDB` memuat semua file di folder itu dan mengurutkannya per `id`, jadi urutan penawaran tetap deterministik.
2. Kodekan efeknya di `duel.gd` dengan `mods(side, "<id>")` di titik yang tepat (lihat tabel §3).
3. Tambahkan nilai AI di `RivalAI.modifier_value`. Tanpa ini modifier bernilai 0 dan rival tidak akan memilihnya.
4. Kalau modifier hanya berguna untuk build tertentu, isi `tag` dengan tag ingredient (misalnya `SPICE`).
5. Tambahkan test di `godot/tests/sim.gd` dan jalankan; setelah itu cek dampaknya ke balance dengan `tests/balance.gd`.

Catatan: `ModifierDef.describe()` mengganti `X` di `text` dengan `amount × stack`. Untuk Plating Pro, teks "xX"
berarti "×2" (huruf `x` kecil lalu angka).

---

## 8. Catatan balance

Dari GRAND_DESIGN §8.2 (300 duel, deck starter, threshold pemain 1 → 2 → 3):

| Rival | Bot | Menang | Modifier Apis / duel |
|---|---|---|---|
| Tony | simple | 76% | 0.30 |
| Tony | smart | 98% | 1.00 |
| Rosa | simple | 38% | 0.30 |
| Rosa | smart | 87% | 0.99 |

Pemain yang hati-hati mendapat ±1 modifier per duel. Tuas utama frekuensi modifier adalah threshold Flow
(`Duel.PLAYER_FLOW`), bukan angka per modifier. Balancing per modifier (misalnya stack tinggi Encore atau Hot Pan)
belum dilakukan; yang diukur `tests/balance.gd` baru jumlah modifier per duel.
