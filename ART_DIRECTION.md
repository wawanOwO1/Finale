# FINALE — Art Direction & Grand Design (v0.1)

> Dokumen pendamping [GDD.md](GDD.md). Menggantikan **GDD §7.1–7.3** (visual & HUD) dan mengusulkan
> perubahan **GDD §4.2–4.3** (Plate → Station Stack berurutan). Dibuat 22 Nov 2026.
> Semua gambar referensi **hanya acuan rasa dan struktur**. Tidak ada aset, karakter, atau layout yang disalin.

---

## 0. Konfirmasi brief

| # | Referensi | Yang diambil untuk Finale | Yang **tidak** diambil |
|---|---|---|---|
| 1 | Duel kartu pixel di atas meja kayu | Pixel art tebal, palet hangat terbatas, kartu krem dengan sudut warna, meja kayu sebagai "panggung", label pita kecil | Karakter goblin/undead, layout 2 baris kartu, tombol aksi |
| 2 | UI kit HUD (shark) | Bahasa bentuk: lencana diamond untuk portrait, bar melengkung, pita miring, chip angka gelap-krem, aksen merah/oranye/teal/mustard | Ikon dan ilustrasinya |
| 3 | Katalog bentuk gauge | **#08/#09 arc** untuk Confidence, **#13 bersegmen** untuk Hype, **#11 diamond** untuk timer intent, **#14 angka di dalam** | Gaya neon biru |
| 4 & 5 | Ekspresi mata/wajah | Emote pop-up di samping kepala lawan: sombong, marah, sedih, dsb. | — |
| 6 | "ROUND 3 / FIGHT!" | Announcer teks besar: countdown → ROUND N → FIGHT!, lalu FINISHED → hasil | Font aslinya |
| 7 | Tiket burger + ikon bahan | **Order Ticket** di atas stack: ikon hidangan + ikon bahan yang dibutuhkan, tercentang saat terisi, ikon metode masak | — |
| 8 | Solitaire 2048 bertumpuk | Bahan **ditumpuk vertikal** per kolom, beberapa kolom sekaligus | Aturan angka 2048 |

**Detail tambahan yang dikonfirmasi**
- Resep punya **urutan seperti di dunia nyata** (burger: roti → isi → roti). Urutan boleh disederhanakan, logikanya tetap masuk akal.
- Layout HUD/UX dibuat dulu di **canvas yang bisa diedit**, baru setelah final dibuat aset pixel-nya.

---

## 1. Pilar visual

1. **Diorama pixel hangat.** Dapur cooking show 3D low-poly yang dirender low-res, terasa seperti pixel art buatan tangan.
2. **Meja adalah panggung.** Kartu, stack, dan tiket hidup di atas meja kayu, sama seperti ref 1. HUD terasa sebagai benda fisik (papan kayu, kertas, pita), bukan panel melayang.
3. **Wajah yang bicara.** Lawan bereaksi lewat emote besar dan jelas. Pemain membaca "mood" lawan tanpa membaca teks.
4. **Setiap momen punya cap.** Mulai, combo, Signature Dish, menang, kalah: semuanya punya teks announcer, suara, dan getaran layar.

---

## 2. Pipeline rendering pixel

### 2.1 Resolusi dasar
| Lapisan | Resolusi internal | Skala ke 1080p | Catatan |
|---|---|---|---|
| Dunia 3D | **640×360** | ×3 | SubViewport, filter `nearest` |
| UI pixel | **640×360** (grid art) | ×3 | Digambar 1 px art = 3 px layar. Teks kecil pakai font pixel 8–11 px |
| Teks panjang (tooltip, deskripsi kartu) | native | — | Boleh resolusi penuh dengan font pixel yang di-scale bulat, supaya tetap terbaca |

640×360 dipilih karena skalanya **bulat** di 720p (×2), 1080p (×3), dan 1440p (×4). Ukuran lain memakai letterbox tipis atau skala terdekat.

### 2.2 Shader dari `leopeltola/Godot-3d-pixelart-demo`
Sudah dicek: lisensi **MIT** (wajib cantumkan di credits). Cara kerjanya:
- Ini shader **outline/highlight**, bukan shader pixelate. Efek pixel datang dari render resolusi rendah.
- Outline gelap dari **depth buffer** (4 tetangga). Highlight terang di tepi dari **normal buffer**.
- Parameter: `shadow_strength` (0.4), `highlight_strength` (0.1), `shadow_color`, `highlight_color`, toggle shadows/highlights.

**⚠️ Risiko teknis:** shader ini dibuat untuk **Forward+**, sementara project kita **Compatibility** (wajib untuk export Web). Normal buffer (`hint_normal_roughness_texture`) tidak ada di Compatibility.

**Rencana:**
1. Porting shader sebagai **material per objek** (disarankan oleh README-nya karena mode post-process punya bug transparansi).
2. Bagian **depth outline** dipertahankan (`hint_depth_texture` tersedia di Compatibility).
3. Bagian **highlight normal** diganti: rekonstruksi normal dari depth, atau rim-light sederhana di shader objek.
4. Tambahan sendiri: **kuantisasi palet** (lookup ke palet 24 warna, §3) dan **snap kamera ke texel** supaya tidak ada pixel "berenang" saat kamera bergerak.
5. Uji di build Web sebelum aset diproduksi massal (Fase 2).

Fallback kalau depth texture bermasalah di Web: outline **inverted hull** (mesh duplikat sedikit lebih besar, back-face, warna gelap). Murah dan aman di semua renderer.

### 2.3 Aturan pemodelan 3D
- Low-poly, **flat/vertex color**, tanpa tekstur detail. Detail kecil (mata, logo) pakai tekstur pixel 16–32 px.
- Ukuran karakter di layar: tinggi ±60–80 px art (pada 640×360). Kepala besar (1:3), siluet terbaca.
- Lampu: 1 key light hangat + ambient. Bayangan keras.

---

## 3. Palet & tipografi

### 3.1 Palet (24 warna, "Market Street")
Diturunkan dari `Pal.gd` saat ini, digeser ke nuansa meja kayu ref 1.

| Grup | Warna |
|---|---|
| Kayu (meja, papan HUD) | `#2a1a10` `#3b2414` `#5a3722` `#7a4e30` `#9c6a42` |
| Kertas (kartu, tiket) | `#fbf3e2` `#f3e3c4` `#d9c39a` |
| Tinta (teks, outline) | `#1e1410` `#3b2414` `#6b4a32` |
| Aksen panas | `#d8342c` `#a8231d` `#e07b28` `#f2b632` |
| Aksen dingin | `#2f6f7a` (teal) `#3f7fae` `#8fb3d1` |
| Alam | `#4d9a4a` `#5ea44f` `#2e5e2c` |
| Spesial | `#8a3fb0` (Signature) `#ffffff` (kilau) `#000000` (bayangan) |

Warna tag bahan tetap seperti `Pal.TAG` (PROTEIN oranye, VEGGIE hijau, dst.) dan dipakai di **sudut kartu**, sama seperti segitiga warna di ref 1.

### 3.2 Font (semua lisensi bebas, cek ulang saat dipasang)
| Pemakaian | Kandidat | Gaya |
|---|---|---|
| Announcer (ROUND, FIGHT!, FINISHED) | font pixel tebal condensed, mis. *Pixel Operator Bold* (CC0) di-scale ×4–×6 | Krem `#fbf3e2` dengan outline tinta 2 px + bayangan |
| Angka besar (HP, biaya kartu) | sama, ×2 | Angka tebal seperti "11" di ref 1 |
| Teks UI & tooltip | *m5x7 / m6x11* (Daniel Linssen, gratis dengan kredit) | Kecil, rapi |

---

## 4. Layout HUD (wireframe, akan diiterasi di canvas)

> Canvas yang bisa diedit: [Finale HUD Layout](https://claude.ai/artifact/2LPfQEPSEpKToxQ2iBWAqF). Isinya Duel HUD, HUD Kit, Station Stack, Emote, dan 4 layar announcer. Canvas itu jadi acuan utama, wireframe teks di bawah hanya ringkasan.

Grid art 640×360. Angka = posisi kira-kira dalam px art.

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ [ROUND 2/5]            ╔═ HYPE ▮▮▮▮▯▯▯▯▯▯ ═╗              [⚙] [📖]        │ y 0–24
│                                                                              │
│                         ◇ Tony  ◠◠◠◠ 24/30 ◠                                 │
│                           [intent ◆ 8]   (😏 emote)                          │
│                              🧑‍🍳 RIVAL (3D)                                   │ y 24–150
│ ┌ STATION 1 ┐ ┌ STATION 2 ┐ ┌ STATION 3 ┐                                    │
│ │ 🎫 ticket │ │ 🎫 ticket │ │ 🎫 ticket │      🧑‍🍳 APIS (3D)                  │
│ │ [Bread  ] │ │ [Butter ] │ │           │                                    │
│ │ [Beef   ] │ │ [Egg    ] │ │  + drop   │                                    │
│ │ [Cheese ] │ │           │ │           │                                    │
│ │ [SERVE 1🔥]│ │ [SERVE  ] │ │           │                                    │ y 150–270
│ └───────────┘ └───────────┘ └───────────┘                                    │
│ ◇APIS ◠◠◠◠◠ 48/60   🔥🔥🔥 Heat      [hand: ▭ ▭ ▭ ▭ ▭]   [Draw 12][Disc 3][END]│ y 270–360
└──────────────────────────────────────────────────────────────────────────────┘
```

### 4.1 Komponen
| Komponen | Bentuk (ref) | Detail |
|---|---|---|
| **Portrait pemain** | Diamond krem (ref 2) | Kiri bawah, ±40 px. Ikon status kecil di atasnya |
| **Confidence pemain** | Arc gauge (ref 3 #08) di samping diamond | Merah, ujung berkilau putih (ref 2). Angka di dalam bar (#14). Bagian Composure = lapisan biru di atas arc |
| **Confidence lawan** | Arc kecil di atas kepala + diamond kecil | Ikut posisi 3D kepala |
| **Intent lawan** | Diamond (ref 3 #11) | Ikon aksi + angka. Intent 2 giliran: diamond terisi setengah |
| **Heat** | 3 pip api | Pip kosong = abu, terisi = oranye berkedip pelan |
| **Hype** | Bar bersegmen 10 (ref 3 #13) di atas tengah | Penuh = pita emas + kilau, kartu Signature muncul |
| **Round** | Chip "ROUND 2 / 5" (ref 2) | Kiri atas. 5 = jumlah duel di Market Street |
| **Station** | Papan kayu vertikal + tiket di atas | Lihat §6 |
| **Tangan** | Kartu krem, kipas tipis | Biaya di kiri atas, sudut warna tag, pita nama saat hover (pita "Plague Rat" di ref 1) |
| **Draw / Discard** | Tumpukan kartu fisik di meja (ref 1) | Angka di chip gelap |
| **End Turn** | Pita miring merah | Kanan bawah |

### 4.2 Prinsip UX
- Semua yang bisa di-drag punya **bayangan** dan sedikit terangkat saat hover.
- **Drop target** (station) menyala saat kartu yang cocok di-drag. Merah tipis kalau langkah salah (§6.3).
- Informasi lawan selalu **di atas**, pemain selalu **di bawah**.
- Target 1080p: elemen yang bisa diklik minimal 16×16 px art (48 px layar).

---

## 5. Emote lawan

Pop-up **di samping kepala lawan** (kanan atas kepala), dalam bubble krem 24×24 px art dengan ekor kecil. Gaya wajah sederhana: mata + mulut saja, mengikuti ref 4 & 5.

| State | Pemicu | Emote | Animasi |
|---|---|---|---|
| **Smug** (ketawa sombong) | Confidence pemain ≤ 30% | Mata `^ ^`, mulut lebar, "HA HA" kecil | Bubble memantul 2×, chef goyang tertawa |
| **Angry** | Confidence lawan ≤ 25% (sekarat) | Alis miring `\ /`, mulut zigzag, urat "💢" | Bubble gemetar, merah berkedip |
| **Sad** | Lawan kalah | Mata `T T` / `; ;`, mulut turun | Bubble pelan turun, chef menunduk |
| **Shocked** | Kena Serve resep ≥ 15 Pressure atau Signature | Mata bulat, mulut "O" | Pop cepat, shake |
| **Confident** | Lawan memasang intent besar (2 giliran) | Satu mata kedip `> ●` | Muncul bersamaan intent |
| **Tired** (opsional) | Lawan kena Flustered | Mata `- -`, keringat | — |

**Aturan:** maksimal 1 emote dalam satu waktu. Durasi 1.5 detik, kecuali **Angry** yang tetap kecil (ikon mini) selama lawan sekarat. Prioritas: Sad > Shocked > Angry > Smug > Confident. Smug dan Angry hanya muncul **sekali per perpindahan ambang**, jadi tidak spam.

Tiap emote adalah sprite 24×24 (2–4 frame). Satu set dipakai semua chef; chef boleh punya warna bubble sendiri.

---

## 6. Station Stack & resep berurutan (usulan Grand Design)

> Ini perubahan **gameplay**, bukan hanya visual. Menggantikan Plate 5 slot di GDD §4.2–4.3.

### 6.1 Aturan
- Ada **3 Station** (kolom) di meja. Tiap station menumpuk bahan **seperti solitaire**: bahan pertama di paling atas kolom, tiap bahan baru menindih ke bawah. Kartu lama hanya terlihat pita nama + ikon tag, kartu terbaru terbuka penuh (bingkai emas = bisa diambil). Maksimal **6** (7 dengan *Bigger Plate*).
- Bahan dari tangan di-drag ke **atas** stack mana pun. Hanya kartu teratas yang bisa disentuh (seperti solitaire).
- Stack **bertahan antar giliran**, sama seperti Plate sekarang. Pemain bisa menyiapkan 2–3 hidangan sekaligus.
- **Serve** memilih 1 station (1 Heat, sekali per giliran). Station itu kosong lagi.
- **Pindah kartu teratas** ke station lain: 1× per giliran, gratis. Ini memberi ruang memperbaiki salah tumpuk.
- **Clear station**: buang seluruh stack ke discard, gratis, mengakhiri kesempatan pindah giliran itu.

### 6.2 Pencocokan
Resep punya **urutan langkah**. Station dibaca dari kartu pertama (atas kolom) ke kartu terbaru (bawah kolom). Di tabel §6.4, "bawah → atas" berarti urutan penaruhan ini.

| Hasil | Syarat | Efek |
|---|---|---|
| **Perfect** | Stack = urutan resep persis | Efek resep ×1.5 (Perfect Order yang sudah ada) |
| **Cooked** | Bahan resep lengkap tapi urutan beda | Efek resep ×1.0 |
| **Garnish** | Bahan tambahan **di atas** resep yang sudah lengkap | +1 Quality per bahan, maks +2 |
| **Improvised** | Tidak cocok resep apa pun | 2 × jumlah bahan Pressure (aturan lama) |

> **Diputuskan 22 Nov:** aturan **lunak** (Perfect/Cooked) dipakai. Urutan wajib tidak dipakai.

### 6.3 Order Ticket (ref 7)
- Begitu kartu pertama masuk station, tiket di atasnya menampilkan **resep paling mungkin**: ikon hidangan + baris ikon bahan sesuai urutan + ikon metode masak (wajan, panggang, rebus).
- Bahan yang sudah ada = ikon terang + centang. Langkah berikutnya = berkedip.
- Kalau stack keluar jalur, tiket berubah jadi "???" (Improvised) dengan warna abu.
- Saat resep lengkap: tiket **"stamp" PERFECT!/COOKED** dengan animasi cap, sudut tiket emas.
- **Diputuskan 22 Nov:** tiket **boleh memberi hint** resep. Ini menggantikan aturan GDD "Recipe Book ditutup saat duel, tanpa hint resep".

### 6.4 Urutan resep (draft, dunia nyata disederhanakan)
Kunci: `TAG` = bahan apa pun bertag itu, *Nama* = bahan kunci.

| Resep | Urutan (bawah → atas) | Logika dapur |
|---|---|---|
| Toast | `CARB` → `FAT` | Roti, lalu oles mentega |
| Omelette | `FAT` → *Egg* → `VEGGIE` | Panaskan mentega, tuang telur, isi sayur |
| Fresh Salad | `VEGGIE` → `VEGGIE` (→ `FAT` garnish) | Sayur, sayur, dressing |
| Classic Steak | `FAT` → *Beef* → `SPICE` | Minyak di wajan, sear daging, basting bawang putih |
| Skewers | `PROTEIN` → `SPICE` | Tusuk daging, bumbui |
| Mixed Grill | `FAT` → `PROTEIN` → `PROTEIN` | Minyak, daging, daging |
| Arrabbiata | `SPICE` → `SAUCE` → `CARB` | Tumis cabai/bawang, saus tomat, masukkan pasta |
| Hot Wings | *Chicken* → `SPICE` → `SPICE` | Ayam, bumbu, bumbu |
| Warm Soup | `VEGGIE` → `PROTEIN` → `SAUCE` | Tumis sayur, daging, tuang kaldu |
| Mac & Cheese | *Pasta* → `FAT` → `DAIRY` | Pasta rebus, mentega, keju |
| Mushroom Risotto | *Rice* → *Mushroom* → `DAIRY` | Nasi, jamur, keju/krim |
| **Burger** (baru, Grill) | *Bread* → *Beef* → *Cheese* → `VEGGIE` → *Bread* | Showcase stack tinggi (5) |
| **Sandwich** (baru, Basics) | *Bread* → `PROTEIN` → `VEGGIE` → *Bread* | Varian burger yang mudah |

Kode sudah siap sebagian: `RecipeDef.requires` sudah berurutan dan `RecipeMatch.in_order()` sudah ada. Perubahan: Plate jadi 3 array, match per station, aturan Garnish, dan urutan `requires` di file `.tres` disesuaikan tabel ini.

---

## 7. Alur match & announcer (ref 6)

| Momen | Urutan layar | Durasi |
|---|---|---|
| **Mulai duel** | Kamera pelan ke meja → **3 · 2 · 1** (angka besar, pop + tick SFX) → **ROUND 2** (kecil di atas) **FIGHT!** (besar) → kartu dibagikan | ±3 s |
| **Combo / resep** | Tiket "stamp" → nama hidangan di pita → angka Pressure terbang | ±1 s |
| **Signature Dish** | Cut-in (GDD §4.5) + teks **"SIGNATURE!"** | ±2 s |
| **Menang** | Emote Sad lawan → **FINISHED** → **YOU WINS!** → layar Victory | ±3 s |
| **Kalah** | Emote Smug lawan → **FINISHED** → **LOSER** (huruf jatuh satu per satu, warna abu-merah) → ringkasan run | ±3 s |

"ROUND N" = duel ke-N di Course Path (Market Street). Variasi teks menang (diacak): *APIS WINS!*, *ORDER UP!*, *CHEF'S KISS!*. Teks kalah tetap **LOSER** supaya kontras.

Gaya teks: krem dengan outline tinta tebal + bayangan jatuh, sedikit miring, masuk dengan *squash & stretch*. Background: strip gelap semi-transparan selebar layar (seperti ref 6).

---

## 8. Daftar aset (untuk produksi setelah layout final)

| Kategori | Aset | Ukuran art | Jumlah |
|---|---|---|---|
| Kartu | Frame kartu bahan, teknik, Signature; punggung kartu | 48×64 | 4 |
| Ilustrasi kartu | 1 per bahan/teknik | 32×32 | ±30 |
| Ikon bahan (tiket) | Versi mini | 12×12 | ±20 |
| Ikon hidangan | 1 per resep | 24×24 | 13 |
| Ikon metode | wajan, panggang, rebus, mentah | 12×12 | 4 |
| HUD | Diamond portrait, arc gauge (frame + fill), bar Hype, pip Heat, chip, pita, tombol | beragam | ±15 |
| Station | Papan kayu, tiket, cap PERFECT/COOKED | 56×120 | 4 |
| Emote | 6 emote × 2–4 frame + bubble | 24×24 | ±20 frame |
| Announcer | 3/2/1, ROUND, FIGHT!, FINISHED, WINS!, LOSER (atau dari font) | — | 6 |
| Portrait | Apis + 5 chef, versi diamond | 40×40 | 6 |
| 3D | Panggung, 2 meja, MC, 5 chef, ±13 hidangan | low-poly | — |

Konvensi file: `godot/assets/pixel/<kategori>/<nama>.png`, tanpa filter, import `Filter: Nearest`, `Mipmaps: off`.

---

## 9. Keputusan

1. ~~Canvas~~ → **HTML canvas di Claude** ([Finale HUD Layout](https://claude.ai/artifact/2LPfQEPSEpKToxQ2iBWAqF)).
2. ~~Aturan urutan~~ → **lunak** (Perfect ×1.5 / Cooked ×1.0).
3. ~~Hint resep~~ → **Order Ticket boleh memberi hint.**
4. ~~Jumlah station~~ → **3**, tampil sebagai tumpukan solitaire.
5. ~~Nama di layar menang~~ → **YOU WINS!** (kalah: LOSER).

---

## 10. Masterplan

Deadline submit 18 Des 2026. Upload pertama 14 Des.

| Fase | Tanggal | Output | Selesai kalau |
|---|---|---|---|
| **0. Brief** | 22 Nov | Dokumen ini | Keputusan §9 dijawab |
| **1. Layout di canvas** | 23–25 Nov | Wireframe HUD duel, Station + tiket, emote, announcer, layar menang/kalah | Kamu approve layout |
| **2. Uji pipeline pixel** | 24–26 Nov | Shader di-port ke Compatibility, SubViewport 640×360, palet + snap kamera, **tes build Web** | Scene graybox terlihat "pixel" di browser, ≥45 fps |
| **3. Station Stack (kode)** | 25–28 Nov | 3 station, urutan resep, Garnish, pindah kartu, tiket (graybox), update `.tres` + test `sim` | Duel penuh jalan dengan aturan baru, test lulus |
| **4. Juice graybox** | 28 Nov–1 Des | Countdown/FIGHT/FINISHED, emote (placeholder), stamp tiket | Semua momen §7 ada, walau masih kotak-kotak |
| **5. Produksi aset pixel** | 1–9 Des | Aset §8 sesuai layout final | Tidak ada placeholder di duel |
| **6. Aset 3D + karakter** | 4–11 Des | Panggung, chef, hidangan dengan material outline | Market Street lengkap |
| **7. Polish & submit** | 12–18 Des | Tutorial, audio, tes 5 resolusi, upload 14 Des | Submit |

**Yang dipotong kalau mundur (berurutan):** emote Tired/Confident → animasi frame emote (pakai 1 frame) → resep baru (Burger/Sandwich) → station ke-3 → snap kamera.

---

## Credits yang perlu dicatat
- *Godot-3d-pixelart-demo* oleh Leo Peltola — MIT.
- Font yang dipakai (sesuai lisensi masing-masing).
