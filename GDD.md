# GDD — *FINALE* (judul sementara) · Versi Jam

> OpenGame Game Jam #1 · Track: **05 Strategy** (deck-builder) + sponsor **fal**, **ElevenLabs** · Solo
> Deadline upload: **18 Des 2026, 23:59 PT** (≈ 19 Des 14:59 WIB) · Target upload pertama: **14 Des**
> Bahasa in-game: **full English** · Tech: **Vite + TypeScript + Three.js** (UI kartu di HTML/CSS)

> **Asal-usul (penting untuk aturan jam):** desain ini diturunkan dari GDD lama *Cooking Show Deckbuilder* (v0.1, 1 Nov 2026), yang isinya hanya dokumen, referensi, dan paper prototype. Belum ada kode atau aset. Aturan jam mengizinkan memakai ulang **ide & mekanik**. Semua kode, aset 3D, gambar, dan audio **dibuat mulai 18 Nov 2026** dan dicatat di git sejak commit pertama sebagai bukti riwayat pengembangan. Gambar referensi hanya dipakai sebagai acuan struktur dan rasa, tidak disalin.

---

## 1. Ringkasan

Roguelike deckbuilder bergaya **anime masak yang heboh**. Kamu adalah koki muda yang menantang chef-chef top kota dalam duel memasak. Susun bahan di piring, selesaikan resep, dan buat lawanmu kehilangan **Confidence** sampai menyerah.

**Pilar desain**
1. **Resep adalah combo.** Bahan yang dimainkan masuk ke **Plate**. Kalau komposisinya cocok dengan resep yang kamu kuasai, kamu bisa **Serve** dengan efek besar.
2. **Dua lapis deckbuilding.** Deck = bahan dan teknik yang kamu punya. **Recipe Book** = apa yang bisa kamu masak dari bahan itu. Keduanya dibangun selama run.
3. **Lebay ala anime masak.** Reaksi dramatis, cut-in, aura, penonton terpukau. Setiap Serve resep harus *terasa* seperti momen.
4. **Kecil tapi selesai.** Satu karakter, satu distrik yang dipoles penuh, run ±20–30 menit.

**Nada:** anime shounen kuliner. Rival sombong, monolog semangat, reaksi berlebihan. Ramah semua umur.

## 2. Setting

- **Kota:** *Saporé City*, kota kuliner fiktif bernuansa internasional.
- **Turnamen:** *The Grand Plate*. Versi jam memuat babak pertama, **Market Street**, yang ditutup duel melawan *"Iron" Bruno*.
- **MC:** **Apis Tetrarch** ("Apis", nama sementara), koki muda tanpa reputasi dari dapur kecil keluarga, yang ingin jadi koki nomor satu di kota.
- **Penyampaian cerita:** intro singkat, dialog satu-dua baris sebelum dan sesudah duel (portrait + text box), VS screen sebelum boss, dan ending pendek dengan teaser distrik berikutnya.

## 3. Core loop

```
Title → New Run (deck awal + Basics Cookbook)
  → Course Path Market Street: setiap langkah pilih 1 dari 2–3 kartu encounter
       [Duel | Elite | Shop | Event | Practice Kitchen]
  → Reward → ... (±9 langkah) → Practice Kitchen → BOSS: "Iron" Bruno
  → Menang: ending + skor run · Kalah: ringkasan run → New Run
```

Tidak ada meta-progression di versi jam (lihat §11).

## 4. Mekanik duel

### 4.1 Stat
| Stat | Fungsi |
|---|---|
| **Confidence** (HP) | Mental chef. 0 = menyerah. Pemain mulai **100** (fase G, 23 Nov; dulu 60), nilainya terbawa antar duel. |
| **Composure** (Block) | Menahan Pressure. Hilang di awal giliran pemiliknya. |
| **Heat** (Energy) | **3** per giliran. Biaya kartu dan Serve. |
| **Pressure** (Damage) | Mengurangi Composure dulu, lalu Confidence lawan. |

### 4.2 Giliran pemain
1. Composure → 0, Heat → 3, draw **5** kartu.
2. Mainkan kartu:
   - **Ingredient** → masuk ke **Plate** (maks **5 slot**). Beberapa punya efek kecil langsung.
   - **Technique** → efek langsung (Pressure, Composure, draw) atau memodifikasi bahan di Plate.
3. **Serve** (tombol, **1 Heat**, sekali per giliran): seluruh isi Plate dihidangkan.
   - Cocok dengan resep yang dikuasai → efek resep + total Quality + Hype.
   - Tidak cocok → *Improvised Dish*: Pressure = 2 × jumlah bahan.
4. End Turn: kartu di tangan dibuang. **Plate tetap ada** ke giliran berikutnya.

> Plate yang bertahan antar giliran adalah keputusan inti: Serve sekarang dengan hasil kecil, atau tahan untuk resep besar sambil menanggung tekanan lawan? Tidak ada mekanik basi (sudah diputuskan). Tekanan datang dari intent dan gimmick lawan.

### 4.3 Pencocokan resep (berbasis tag)
> Usulan pengganti: 3 Station bertumpuk dengan resep berurutan. Lihat [ART_DIRECTION.md §6](ART_DIRECTION.md#6-station-stack--resep-berurutan-usulan-grand-design).

| Tag | Contoh bahan |
|---|---|
| `PROTEIN` | Egg, Chicken, Beef, Fish |
| `CARB` | Rice, Bread, Pasta |
| `VEGGIE` | Tomato, Onion, Mushroom |
| `FAT` | Butter, Olive Oil |
| `DAIRY` | Cheese, Milk, Cream |
| `SPICE` | Chili, Garlic, Pepper |
| `SAUCE` | Stock, Tomato Sauce, Soy Sauce |

- Plate harus **mengandung** semua tag yang diminta resep. Bahan berlebih boleh dan menambah Quality.
- Resep tingkat tinggi bisa meminta **bahan kunci** (mis. *Classic Steak* butuh `Beef`).
- Jika lebih dari satu resep cocok, **pemain memilih**. UI menampilkan resep yang cocok dan yang **kurang 1 tag** secara real-time.

### 4.4 Quality & Hype
- Tiap bahan punya **Quality** 1–3. Upgrade dan teknik tertentu menaikkannya.
- **Efek resep = nilai dasar + total Quality di Plate.**
- **Hype Meter** (penonton): +25 setiap Serve resep (lebih banyak untuk resep tier tinggi), plus dari kartu tertentu. Saat penuh (100), **Signature Dish** terbuka.

### 4.5 Signature Dish — momen anime
- Kartu khusus MC yang muncul di tangan saat Hype penuh, sekali per duel.
- Efeknya: Serve Plate saat ini dengan efek **×2**, lalu **cut-in sinematik**: close-up chef, aura, speed lines, teks SFX besar, reaksi lawan dan penonton.
- Ini "money shot" untuk GIF, trailer, dan kesan juri.

### 4.6 Lawan
> **Diganti 22 Nov 2026:** rival kini drafting dengan aturan yang sama dengan pemain (kartu tertutup), tanpa Intent. Lihat [GRAND_DESIGN.md](GRAND_DESIGN.md) untuk turn sequence, Rival AI, RNG, Chef's Flow, dan Almanac. Isi di bawah ini dipertahankan sebagai riwayat.

- Selalu **1 lawan 1**. Lawan punya Confidence, Composure, dan **Intent** yang terlihat:
  - 🔪 *Prepping*: akan memberi X Pressure
  - 🛡️ *Composed*: menambah Composure
  - 🍳 *Cooking [Nama Hidangan] (2 turn)*: serangan besar yang di-telegraph
  - 😤 *Taunt*: memberi debuff
- Variasi datang dari pola intent dan **gimmick** tiap chef.

### 4.7 Status (semua punya tooltip)
| Status | Efek |
|---|---|
| **Spicy** | Kehilangan X Confidence di awal giliran, lalu X−1. |
| **Flustered** | Pressure yang diberikan −25%. |
| **Rattled** | Pressure yang diterima +50%. |
| **Burnt** | Serve berikutnya −50% efek. |
| **Focus** | +X Pressure untuk semua serangan (permanen di duel). |
| **Inspired** | Draw +1 giliran berikutnya. |

## 5. Progresi dalam run

### 5.1 Course Path
- Pengganti map bercabang. Setelah setiap node, pemain memilih **1 dari 2–3 kartu encounter** (ikon tipe + petunjuk reward). Market Street punya ±9 pilihan, lalu Boss.
- **Aturan generator:** Elite tidak muncul di 3 node pertama; minimal 1 Shop dan 1 Practice Kitchen; node sebelum Boss selalu Practice Kitchen.
- Di atasnya ada strip progres kecil ala District Select (ref 02): node yang sudah lewat, posisi sekarang, dan boss di ujung.

### 5.2 Reward
| Sumber | Reward |
|---|---|
| Duel | Pilih 1 dari 3 kartu + Tips |
| Elite | Kartu + **Kitchen Tool** (relic) + kesempatan Recipe Book |
| Shop | Kartu, Kitchen Tool, **Recipe Book**, hapus kartu |
| Boss | Menang run |

### 5.3 Recipe Book
- Tiap buku berisi **2–3 resep bertema**. Membeli buku berarti menguasai semua resepnya.
- Pemain mulai dengan **Basics Cookbook**. Buku lain dibeli di Shop (75–150 Tips) atau didapat dari Elite.

| Buku | Arah build | Versi jam |
|---|---|---|
| Basics Cookbook | Serba bisa (starter) | ✅ |
| Grill Master's Notes | Pressure besar | ✅ |
| Spice Route Journal | Stack Spicy | ✅ |
| Comfort Food Diary | Sustain/Composure | ✅ |
| Pâtisserie Secrets | Combo panjang, skala Quality | Stretch |
| Speed Kitchen Manual | Resep 2 bahan, Serve tiap giliran | Stretch |

### 5.4 Practice Kitchen (rest site)
Pilih satu: **Rest** (pulihkan 30% Confidence), **Upgrade** satu kartu, atau **Master a Recipe** (efek dasar resep naik).

## 6. Konten versi jam

### 6.1 Starter Deck (10)
| Kartu | Tipe | Biaya | Efek |
|---|---|---|---|
| Egg ×2 | `PROTEIN` | 0 | Q1 |
| Bread | `CARB` | 0 | Q1 |
| Tomato | `VEGGIE` | 0 | Q1 |
| Butter | `FAT` | 0 | Q1 |
| Quick Chop ×3 | Technique | 1 | 6 Pressure |
| Deep Breath ×2 | Technique | 1 | 5 Composure |

### 6.2 Pool reward (draft, target ±30 kartu total)
| Kartu | Tipe | Biaya | Efek |
|---|---|---|---|
| Chicken | `PROTEIN` | 1 | Q2 |
| Beef | `PROTEIN` | 1 | Q2, bahan kunci steak |
| Fish | `PROTEIN` | 1 | Q2, +3 Composure |
| Rice | `CARB` | 0 | Q1, draw 1 |
| Pasta | `CARB` | 1 | Q2 |
| Onion | `VEGGIE` | 0 | Q1, lawan Flustered 1 |
| Mushroom | `VEGGIE` | 1 | Q2 |
| Chili | `SPICE` | 0 | Q1, lawan Spicy 2 |
| Garlic | `SPICE` | 0 | Q1, +2 Composure |
| Cheese | `DAIRY` | 1 | Q2 |
| Cream | `DAIRY` | 1 | Q1, +1 Quality ke bahan lain di Plate |
| Stock | `SAUCE` | 0 | Q1 |
| Tomato Sauce | `SAUCE` | 1 | Q2 |
| Olive Oil | `FAT` | 0 | Q1, +1 Heat giliran berikutnya |
| Sauté | Technique | 1 | +1 Quality untuk semua bahan di Plate |
| Flambé | Technique | 2 | 12 Pressure, Hype +10 |
| Mise en Place | Technique | 0 | Draw 2 |
| Taste Test | Technique | 1 | Lihat 3 kartu teratas, ambil 1 Ingredient |
| Stare Down | Technique | 1 | Lawan Rattled 2 |
| Plating Art | Technique | 1 | Serve berikutnya Hype ×2 |
| Second Helping | Technique | 2 | Kembalikan 1 bahan dari Serve terakhir ke tangan |
| Clean Station | Technique | 0 | Buang 1 bahan dari Plate, draw 1 |
| Crowd Pleaser | Technique | 1 | Hype +20 |

### 6.3 Resep (±11)
| Resep | Buku | Butuh | Efek dasar |
|---|---|---|---|
| **Omelette** | Basics | `PROTEIN` + `FAT` + `VEGGIE` | 10 Pressure, 5 Composure |
| **Toast** | Basics | `CARB` + `FAT` | 6 Pressure, draw 1 |
| **Fresh Salad** | Basics | `VEGGIE` + `VEGGIE` | 8 Composure, hapus 1 debuff |
| **Classic Steak** | Grill Master | `Beef` + `FAT` + `SPICE` | 20 Pressure |
| **Skewers** | Grill Master | `PROTEIN` + `SPICE` | 8 Pressure, Focus 1 |
| **Mixed Grill** | Grill Master | `PROTEIN` + `PROTEIN` + `FAT` | 16 Pressure, lawan Rattled 1 |
| **Arrabbiata** | Spice Route | `CARB` + `SAUCE` + `SPICE` | 8 Pressure, Spicy 4 |
| **Hot Wings** | Spice Route | `PROTEIN` + `SPICE` + `SPICE` | 6 Pressure, Spicy 6 |
| **Warm Soup** | Comfort Food | `PROTEIN` + `VEGGIE` + `SAUCE` | Pulihkan 5 Confidence, 8 Composure |
| **Mac & Cheese** | Comfort Food | `CARB` + `DAIRY` + `FAT` | 8 Pressure, 8 Composure |
| **Mushroom Risotto** | Comfort Food | `CARB` + `VEGGIE` + `DAIRY` | 10 Composure, Inspired |

*Semua efek ditambah total Quality di Plate.*

### 6.4 Kitchen Tools (±8)
- **Grandma's Pan**: Serve resep pertama tiap duel +5 Pressure.
- **Sharp Santoku**: Technique yang memberi Pressure +2.
- **Bigger Plate**: Plate menampung 6 bahan.
- **Lucky Apron**: mulai duel dengan Hype 25.
- **Spice Rack**: setiap memainkan `SPICE`, +1 Composure.
- **Butter Dish**: bahan `FAT` +1 Quality.
- **Cast-Iron Lid**: Plate yang ditahan ke giliran berikutnya memberi +3 Composure.
- **Food Critic's Pen**: Signature Dish +50%.

### 6.5 Lawan (Market Street)
| Lawan | Tipe | Confidence | Gimmick |
|---|---|---|---|
| **Tony**, street noodle cook | Duel | ±45 (fase G; dulu 30) | Pola sederhana. Lawan tutorial. |
| **Rosa**, taco truck queen | Duel | ±50 (fase G; dulu 38) | Sering Taunt (Flustered). |
| **Marco**, pizza showman | Duel | ±42 (belum dituning, Confidence pemain kini 100) | Cooking 2 turn yang besar, mengajarkan pentingnya Composure. |
| **Élodie**, rival patissière | Elite | ±60 | Saat Plate-mu penuh (5), ia membuatmu Rattled. |
| **"Iron" Bruno**, butcher-turned-grill master | Boss | ±110 (2 fase) | Fase 1: setiap 2 giliran membuatmu **Burnt**. Fase 2 (≤50%): Focus bertambah tiap giliran. Harus diselesaikan dengan cepat. |

### 6.6 Event (3)
Pilihan teks singkat dengan portrait. Contohnya: pedagang bahan misterius, kritikus makanan meminta cicip, dan bantu pedagang yang kewalahan.

## 7. Visual & presentasi

> **Diperbarui 22 Nov 2026:** arah visual, HUD, emote, announcer, dan usulan **Station Stack** (resep berurutan, menggantikan Plate di §4.2–4.3) ada di [ART_DIRECTION.md](ART_DIRECTION.md). Bagian 7.1–7.3 di bawah ini adalah versi lama dan dipertahankan sebagai riwayat.

### 7.1 Gaya (acuan ref 01 / gambar 1)
- **Low poly flat-shaded** dengan **palet terbatas**. Market Street memakai oranye hangat dan krem, aksen merah. Shading minim, siluet tegas, detail dari bentuk, bukan tekstur.
- **Kamera fix, sudut tinggi ala diorama.** Panggung cooking show terlihat seperti miniatur di atas meja. Dua meja masak berhadapan, penonton berupa blok siluet.
- **Pixel filter (opsional, diuji minggu 1):** render ke resolusi lebih rendah lalu upscale nearest-neighbor. Bisa dinyalakan atau dimatikan dengan satu toggle untuk perbandingan A/B.
- Nuansa anime datang dari **ekspresi, pose, dan momen sinematik**, bukan shading.
- **Proporsi karakter:** stylized, kepala sedikit besar, terbaca dari kamera tinggi.

### 7.2 HUD (acuan gambar 1)
- Confidence dalam **lencana bulat besar di kiri bawah**, Tips di sebelahnya, ikon status kecil di atasnya.
- Kartu di bawah layar. Plate di tengah meja, lengkap dengan indikator resep yang cocok atau hampir cocok.
- Hype Meter berupa bar penonton di atas panggung. Intent lawan muncul di atas kepalanya.

### 7.3 UI layar (struktur dari referensi, bukan visualnya)
| Layar | Acuan | Yang diambil |
|---|---|---|
| Duel | Gambar 1 | Palet terbatas, flat shading, kamera diorama, HUD lencana bulat |
| Course Path | Ref 02 | Kartu encounter besar; state selesai/sekarang/terkunci terbaca sekilas |
| Reward / reveal Recipe Book | Ref 04 | Overlay gelap, kartu muncul dengan animasi reveal, "Click anywhere to continue" |
| Pilih kartu / Kitchen Tool | Gambar 3 | 3 pilihan dengan **bingkai tebal kartun**, tooltip keyword saat hover, uang di kiri bawah |
| Tutorial | Gambar 2 | Modal berhalaman (Previous / Next, `1/2`), screenshot dengan highlight dan panah keterangan. Muncul kontekstual saat fitur pertama kali muncul (Plate, Serve, Hype, Recipe Book), bisa dibuka ulang dari menu |
| Deck & resep viewer | Ref 05 | Read-only, koleksi + counter |

**Prinsip UX**
- **Semua pilihan berbentuk kartu:** encounter, reward, tool, buku resep.
- **State terbaca sekilas:** selesai = centang, sekarang = terang dan berbingkai, terkunci = gelap + gembok.
- **Reveal itu momen.** Selalu ada overlay, animasi, dan suara.
- **Tooltip keyword di mana-mana.**

### 7.4 Aset (track fal)
- **3D:** panggung Market Street, MC, 5 chef (Tony, Rosa, Marco, Élodie, Bruno), dan ±11 model hidangan yang muncul saat Serve. Dibuat lewat image-to-3D di **fal** dari concept art fal, lalu dirapikan dan dibuat flat-shaded di engine (vertex color/palet), atau dimodel low-poly sederhana kalau hasilnya kurang.
- **2D:** ilustrasi kartu dan portrait dialog dari **fal**, dengan prompt/style reference tetap supaya konsisten.
- **Animasi minimal per chef:** idle, cook, hit, taunt, defeated. Kalau rigging terlalu mahal, pakai animasi prosedural (bob, squash & stretch, shake).
- **Momen wajib:** cut-in Signature Dish (render 3D close-up + overlay 2D speed lines), reaksi lawan saat Confidence habis, VS screen sebelum Bruno.

## 8. Audio (track ElevenLabs)
- **Voice line pendek** tiap chef (taunt, kena Serve besar, menyerah), MC (teriakan Signature Dish), dan announcer cooking show ("SERVE!", "INCREDIBLE!").
- **SFX:** desis wajan, potong, piring, sorakan penonton, cut-in whoosh.
- **Musik:** tema duel upbeat dan tema boss. Pakai ElevenLabs Music kalau lisensinya memungkinkan.
- Semua audio dibuat saat development dan disimpan sebagai file di build. **Tidak ada API key di game.**

## 9. Arsitektur teknis (Three.js)
Prinsip dari GDD lama dipertahankan, diterjemahkan ke TypeScript:

```
src/
  data/       cards.ts, recipes.ts, books.ts, enemies.ts, tools.ts, events.ts
  core/       combat (state machine), plate, deck, intent AI, effects, statuses
  run/        runState, coursePath, save (localStorage)
  events/     eventBus (card_played, dish_served, turn_started, pressure_dealt…)
  render3d/   stage, chefs, dishes, camera, pixel filter, cut-in
  ui/         kartu, plate, HUD, reward, shop, tutorial modal, tooltip
```

- **Data-driven:** menambah konten = menambah entri data, bukan menulis logika baru.
- **Effect composable:** kartu, resep, dan Kitchen Tool memakai sistem efek yang sama.
- **Logika terpisah dari visual:** combat bisa jalan dan dites tanpa 3D. Visual mendengarkan event bus.
- **Satu save:** run yang sedang berjalan di `localStorage`, dihapus saat run selesai.

**Checklist syarat jam**
- [ ] Build statis, `index.html` di root
- [ ] Frame pertama < 10 detik, download awal < 50 MB, 45+ fps di 1080p
- [ ] Responsif di 1920×1080, 1366×768, 2560×1440, 3440×1440, 1024×640
- [ ] Tanpa login, iklan, tracking, atau API key di build
- [ ] Sinyal `og:ready` via SDK OpenGame
- [ ] Credit dan cek terms fal & ElevenLabs
- [ ] Bisa dimainkan penuh dengan mouse
- [ ] Git sejak hari pertama (bukti riwayat pengembangan)

## 10. Jadwal

| Minggu | Tanggal | Fokus | Milestone |
|---|---|---|---|
| 1 | 22–28 Nov | Setup project, combat inti (deck, Heat, Plate, Serve, resep, Quality), 1 lawan dengan intent, HUD graybox, uji pixel filter A/B | **Satu duel graybox bisa dimainkan** |
| 2 | 29 Nov–5 Des | Status, Hype + Signature Dish (tanpa sinematik), 5 lawan, Course Path, reward, Shop + Recipe Book, Practice Kitchen, event, save | **Satu run penuh graybox** |
| 3 | 6–12 Des | Aset fal (panggung, chef, hidangan, kartu), UI final, cut-in, VS screen, audio ElevenLabs | **Vertical slice Market Street** |
| 4 | 13–18 Des | Tutorial, juice, balancing, tes 5 ukuran window, **upload pertama 14 Des**, perbaikan dari review. Final paling lambat 17 Des | **Submit** |

**Kalau jadwal mundur, yang dipotong berurutan:** event → Marco → Kitchen Tools 8 → 5 → animasi rig (ganti prosedural) → fase 2 Bruno.

## 11. Dipotong dari GDD lama (untuk versi jam)

| Fitur GDD lama | Status jam | Alasan |
|---|---|---|
| 3 distrik (Gourmet Avenue, Grand Arena) | **Stretch:** Gourmet Avenue + Madame Céleste kalau run 1 sudah selesai di minggu 3 | Scope 4 minggu |
| Meta-progression (Chef Rank, Kitchen Prep, Challenges) | **Dipotong** | Juri bermain 1–2 run, jadi unlock tidak akan terlihat |
| Secret Seasoning (consumable) | **Dipotong** | Sistem tambahan, nilai kecil untuk jam |
| Settings resolusi/fullscreen | **Diganti:** hanya volume | Game berjalan di browser |
| Build Windows / itch.io | **Diganti:** web-only OpenGame | Aturan jam |
| Godot 4 | **Diganti (final):** Three.js | Pemula; aku bisa menulis dan mengetes kode secara langsung |
| "Tanpa voice acting" | **Diubah:** voice line pendek via ElevenLabs | Track sponsor |

## 12. Pertanyaan terbuka
- [x] ~~Judul~~ → **Finale** (sementara).
- [x] ~~Nama MC~~ → **Apis Tetrarch** (Apis), sementara.
- [ ] **Pixel filter:** dipakai, atau flat-shaded bersih seperti referensi? Diputuskan setelah uji A/B minggu 1.
- [ ] **Juri sebagai modifier per duel** (mis. juri suka pedas: resep `SPICE` +30%)? Kandidat stretch.
