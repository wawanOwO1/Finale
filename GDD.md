# GDD — *FINALE* (judul sementara) · Versi Jam

> OpenGame Game Jam #1 · Track: **05 Strategy** (deck-builder) + sponsor **fal**, **ElevenLabs** · Solo
> Deadline upload: **18 Des 2026, 23:59 PT** (≈ 19 Des 14:59 WIB) · Target upload pertama: **14 Des**
> Bahasa in-game: **full English** · Tech: **Godot 4.7** (renderer Compatibility, export Web) di `godot/`

> **Diperbarui 24 Nov 2026** agar sesuai kode. Perubahan besar dari versi 18 Nov: **Godot** menggantikan Vite/TS/Three.js (versi web lama di `src/` hanya referensi), **Station Stack** menggantikan Plate, **rival drafting** menggantikan Intent, dan ada sistem baru (Chef's Flow, Almanac, RNG adil). Dokumen pendamping: [GRAND_DESIGN.md](GRAND_DESIGN.md) (giliran, rival AI, RNG, Flow, Almanac), [ART_DIRECTION.md](ART_DIRECTION.md) (visual, HUD, Station Stack), [MODIFIERS.md](MODIFIERS.md).
> Tanda status: ✅ sudah ada di kode · ⏳ belum dikerjakan · ✂️ dipotong.

> **Asal-usul (penting untuk aturan jam):** desain ini diturunkan dari GDD lama *Cooking Show Deckbuilder* (v0.1, 1 Nov 2026), yang isinya hanya dokumen, referensi, dan paper prototype. Belum ada kode atau aset. Aturan jam mengizinkan memakai ulang **ide & mekanik**. Semua kode, aset 3D, gambar, dan audio **dibuat mulai 18 Nov 2026** dan dicatat di git sejak commit pertama sebagai bukti riwayat pengembangan. Gambar referensi hanya dipakai sebagai acuan struktur dan rasa, tidak disalin.

---

## 1. Ringkasan

Roguelike deckbuilder bergaya **anime masak yang heboh**. Kamu adalah koki muda yang menantang chef-chef top kota dalam duel memasak. Susun bahan di **Station**, selesaikan resep, dan buat lawanmu kehilangan **Confidence** sampai menyerah.

**Pilar desain**
1. **Resep adalah combo, dan urutan itu penting.** Bahan yang dimainkan menumpuk di **Station** seperti solitaire. Urutan yang pas dengan resep memberi **Perfect Order** (×1.5), bahan lengkap tapi urutan beda tetap **Cooked** (×1).
2. **Dua lapis deckbuilding.** Deck = bahan dan teknik yang kamu punya. **Recipe Book** = apa yang bisa kamu masak dari bahan itu. Keduanya dibangun selama run.
3. **Lawan bermain dengan aturan yang sama.** Rival punya deck, tangan, Heat, dan 2 Station sendiri. Kartunya tertutup, dan tidak ada yang dicurangi (lihat §4.9).
4. **Lebay ala anime masak.** Reaksi dramatis, cut-in, aura, penonton terpukau. Setiap Serve resep harus *terasa* seperti momen.
5. **Kecil tapi selesai.** Satu karakter, satu distrik yang dipoles penuh, run ±20–30 menit.

**Nada:** anime shounen kuliner. Rival sombong, monolog semangat, reaksi berlebihan. Ramah semua umur.

## 2. Setting

- **Kota:** *Saporé City*, kota kuliner fiktif bernuansa internasional.
- **Turnamen:** *The Grand Plate*. Versi jam memuat babak pertama, **Market Street**, yang ditutup duel melawan *"Iron" Bruno*.
- **MC:** **Apis Tetrarch** ("Apis", nama sementara), koki muda tanpa reputasi dari dapur kecil keluarga, yang ingin jadi koki nomor satu di kota.
- **Penyampaian cerita:** ⏳ intro singkat, dialog satu-dua baris sebelum dan sesudah duel (portrait + text box), VS screen sebelum boss, dan ending pendek dengan teaser distrik berikutnya.

## 3. Core loop

```
Title → New Run (deck awal + Basics Cookbook)                              ⏳
  → Course Path Market Street: setiap langkah pilih 1 dari 2–3 kartu encounter ⏳
       [Duel | Elite | Shop | Event | Practice Kitchen]
  → Reward → ... (±9 langkah) → Practice Kitchen → BOSS: "Iron" Bruno      ⏳
  → Menang: ending + skor run · Kalah: ringkasan run → New Run             ⏳
```

Yang sudah jalan saat ini hanya **satu duel** (Apis vs Tony atau Rosa), disetel lewat Inspector node `Main` (`Enemy Id`, `Dev Deck`, `Start Hype`). Lapisan run di atasnya belum ada. Tidak ada meta-progression di versi jam (lihat §11).

## 4. Mekanik duel ✅

### 4.1 Stat
| Stat | Fungsi |
|---|---|
| **Confidence** (HP) | Mental chef. 0 = menyerah. Apis mulai **100** (`Duel.PLAYER_CONFIDENCE`), terbawa antar duel. |
| **Composure** (Block) | Menahan Pressure. Hilang di awal giliran pemiliknya. |
| **Heat** (Energy) | **3** per giliran. Biaya kartu dan Serve. |
| **Pressure** (Damage) | Mengurangi Composure dulu, lalu Confidence lawan. |

### 4.2 Giliran pemain
Urutan tetap: banner **YOUR TURN** → giliran pemain (tanpa timer) → banner **RIVAL'S TURN** → rival drafting (dianimasikan) → loop sampai ada yang menyerah. Detail waktu dan arsitektur ada di [GRAND_DESIGN.md §1](GRAND_DESIGN.md).

1. Composure → 0, Heat → 3, draw **5** kartu.
2. Mainkan kartu (di-**drag**):
   - **Ingredient** → seret ke salah satu dari **2 Station**. Beberapa punya efek kecil langsung.
   - **Technique** → seret ke atas keluar dari tangan. Efek langsung (Pressure, Composure, draw) atau memodifikasi bahan.
3. **Serve** (tombol per Station, **1 Heat**, sekali per giliran): seluruh isi Station itu dihidangkan. Station kosong lagi.
4. Opsional, gratis: **pindah kartu teratas** ke Station lain (sekali per giliran) atau **Clear** Station (buang seluruh tumpukan, memakai jatah pindah yang sama).
5. End Turn (`E`): kartu di tangan dibuang. **Station tetap ada** ke giliran berikutnya.

> Station yang bertahan antar giliran adalah keputusan inti: Serve sekarang dengan hasil kecil, atau tahan untuk resep besar sambil menanggung tekanan lawan? Kamu bisa menyiapkan dua hidangan sekaligus.

### 4.3 Station Stack
- **2 Station** per sisi (dari 3, diputuskan 23 Nov setelah playtest), maksimal **6** kartu per Station (**7** dengan *Bigger Plate*).
- Bahan menumpuk ke bawah seperti solitaire. Kartu lama hanya terlihat pita nama + ikon tag, kartu terbaru terbuka penuh (bingkai emas = bisa diambil). Hanya kartu teratas yang bisa di-drag.
- **Order Ticket** di atas tiap Station menampilkan **resep paling mungkin**, urutan bahan, dan langkah berikutnya (berkedip). Keluar jalur → "???" abu-abu. Resep lengkap → cap **PERFECT!** / **COOKED**. Tiket boleh memberi hint, jadi Recipe Book tidak ditutup saat duel.

### 4.4 Pencocokan resep (tag + urutan)
| Hasil | Syarat | Efek |
|---|---|---|
| **Perfect** | Stack = urutan resep persis dari kartu pertama | Efek resep **×1.5** |
| **Cooked** | Bahan resep lengkap, urutan beda | Efek resep ×1.0 |
| **Garnish** | Bahan tambahan setelah resep lengkap | +1 Quality per bahan (maks +2) |
| **Improvised** | Tidak cocok resep apa pun | Pressure = 2 × jumlah bahan |

| Tag | Contoh bahan |
|---|---|
| `PROTEIN` | Egg, Chicken, Beef, Fish |
| `CARB` | Rice, Bread, Pasta |
| `VEGGIE` | Tomato, Onion, Mushroom |
| `FAT` | Butter, Olive Oil |
| `DAIRY` | Cheese, Milk, Cream |
| `SPICE` | Chili, Garlic, Pepper |
| `SAUCE` | Stock, Tomato Sauce, Soy Sauce |

- Resep meminta tag (`FAT`) atau **bahan kunci** (`card:beef`) pada tiap langkahnya. Urutan lengkap tiap resep ada di [ART_DIRECTION.md §6.4](ART_DIRECTION.md), acuan akhirnya `godot/data/recipes/*.tres`.
- Kalau lebih dari satu resep cocok, UI menampilkan yang cocok dan yang **kurang satu langkah** secara real-time.

### 4.5 Quality & Hype
- Tiap bahan punya **Quality** 1–3. Upgrade dan teknik tertentu menaikkannya.
- **Efek resep = (nilai dasar + total Quality di Station) × pengali Perfect.**
- **Hype Meter** (penonton): tiap resep punya nilai Hype sendiri (Omelette 25, Sandwich 30, Burger 40, dst.), plus dari kartu tertentu. Saat penuh (100), **Signature Dish** terbuka.

### 4.6 Signature Dish — momen anime
- Kartu khusus MC yang muncul di tangan saat Hype penuh, sekali per duel. **Hanya untuk Apis**: Hype rival hanya meter penonton.
- Efeknya: Serve Station dengan efek **×2**, lalu **cut-in sinematik**: close-up chef, aura, speed lines, teks SFX besar, reaksi lawan dan penonton. ✅ efek, ⏳ cut-in sinematik.
- Ini "money shot" untuk GIF, trailer, dan kesan juri.

### 4.7 Chef's Flow & Modifier ✅
- Setiap Serve **Perfect Order** = +1 Flow. Threshold pemain **1 → 2 → 3** (lalu tetap 3), tercapai → pilih **1 dari 3 modifier**.
- Per duel: Flow dan modifier reset di awal duel berikutnya, bisa di-stack. Rival juga mendapat modifier (threshold lebih tinggi untuk rival awal).
- 10 modifier awal (Hot Pan, Steady Hands, Encore, Extra Burner, Prep Cook, Crowd Favorite, Spice Whisperer, Free Move, Mise Master, Plating Pro). Daftar dan aturan penawaran: [GRAND_DESIGN.md §5](GRAND_DESIGN.md), [MODIFIERS.md](MODIFIERS.md).

| Meter | Naik dari | Hadiah | Sifat |
|---|---|---|---|
| Hype | Serve resep apa pun | Signature Dish | Ledakan sekali pakai |
| Chef's Flow | Serve Perfect Order | Modifier | Permanen dalam duel, bertumpuk |

### 4.8 Status (semua punya tooltip)
| Status | Efek |
|---|---|
| **Spicy** | Kehilangan X Confidence di awal giliran, lalu X−1. |
| **Flustered** | Pressure yang diberikan −25%. |
| **Rattled** | Pressure yang diterima +50%. |
| **Burnt** | Serve berikutnya −50% efek. |
| **Focus** | +X Pressure untuk semua serangan (permanen di duel). |
| **Inspired** | Draw +1 giliran berikutnya. |

### 4.9 Lawan: rival drafting ✅
Menggantikan sistem Intent (§4.6 versi lama). Selalu **1 lawan 1**, dan rival bermain dengan aturan yang sama dengan pemain.

- Rival punya **deck, Recipe Book, tangan, Heat, dan 2 Station**. `RivalAI` memilih satu aksi per langkah: taruh bahan, mainkan Technique, Serve, atau End Turn. Profil AI: `greedy` (Tony), `trickster` (Rosa), `showman` (Marco), `patient` (Élodie), `boss` (Bruno).
- **Informasi:** pemain melihat punggung kartu (jumlahnya) di tangan dan Station rival, Heat, damage, buff/debuff, dan hidangan yang dihidangkan (nama + PERFECT/COOKED) saat Serve. Isi kartu rival tidak terlihat. Pengganti Intent adalah **mood** (emote Confident, Wary, Smug, Angry).
- **Janji fair:** rival memakai deck, shuffle, dan aturan pity yang sama; tidak melihat tangan atau isi Station pemain; draw-nya tidak dicurangi.
- **RNG:** output duel deterministik (damage, Quality, efek). Yang random hanya input: shuffle, draw, penawaran. Ada anti-clump shuffle dan **Mise en Place** (jaminan tangan punya minimal satu bahan, tampil "✨ Mise en place!"). Stream RNG terpisah per tujuan supaya keputusan AI tidak menggeser draw pemain ([GRAND_DESIGN.md §4](GRAND_DESIGN.md)).
- Tahan klik / Space saat giliran rival = percepat ×3.

### 4.10 Almanac ✅
Buku pengetahuan di HUD (tombol buku atau `Tab`, mem-pause game). Tab Ingredients, Techniques, Recipes, Rivals, Keywords. Entri terbuka saat ditemukan (deck, reward/shop, atau rival menyajikannya), disimpan lintas run di `user://almanac.save`. Ini **pengetahuan, bukan kekuatan**, jadi tidak melanggar keputusan tanpa meta-progression. Ada **combination finder** di tab Recipes.

## 5. Progresi dalam run ⏳

### 5.1 Course Path
- Pengganti map bercabang. Setelah setiap node, pemain memilih **1 dari 2–3 kartu encounter** (ikon tipe + petunjuk reward). Market Street punya ±9 pilihan, lalu Boss.
- **Aturan generator:** Elite tidak muncul di 3 node pertama; minimal 1 Shop dan 1 Practice Kitchen; node sebelum Boss selalu Practice Kitchen.
- Di atasnya ada strip progres kecil: node yang sudah lewat, posisi sekarang, dan boss di ujung. "ROUND N" di announcer = duel ke-N.

### 5.2 Reward
| Sumber | Reward |
|---|---|
| Duel | Pilih 1 dari 3 kartu + Tips |
| Elite | Kartu + **Kitchen Tool** (relic) + kesempatan Recipe Book |
| Shop | Kartu, Kitchen Tool, **Recipe Book**, hapus kartu |
| Boss | Menang run |

Penawaran reward memakai stream RNG `offers` (reproducible dari satu seed run).

### 5.3 Recipe Book
- Tiap buku berisi **2–3 resep bertema**. Membeli buku berarti menguasai semua resepnya.
- Pemain mulai dengan **Basics Cookbook**. Buku lain dibeli di Shop (75–150 Tips) atau didapat dari Elite.

| Buku | Arah build | Status |
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

### 6.1 Starter Deck (10) ✅
| Kartu | Tipe | Biaya | Efek |
|---|---|---|---|
| Egg ×2 | `PROTEIN` | 0 | Q1 |
| Bread | `CARB` | 0 | Q1 |
| Tomato | `VEGGIE` | 0 | Q1 |
| Butter | `FAT` | 0 | Q1 |
| Quick Chop ×3 | Technique | 1 | 6 Pressure |
| Deep Breath ×2 | Technique | 1 | 5 Composure |

### 6.2 Pool reward (target ±30 kartu total; **22 ada, 7 belum**)
| Kartu | Tipe | Biaya | Efek | Status |
|---|---|---|---|---|
| Chicken | `PROTEIN` | 1 | Q2 | ✅ |
| Beef | `PROTEIN` | 1 | Q2, bahan kunci steak | ✅ |
| Fish | `PROTEIN` | 1 | Q2, +3 Composure | ✅ |
| Rice | `CARB` | 0 | Q1, draw 1 | ✅ |
| Pasta | `CARB` | 1 | Q2 | ✅ |
| Onion | `VEGGIE` | 0 | Q1, lawan Flustered 1 | ✅ |
| Mushroom | `VEGGIE` | 1 | Q2 | ✅ |
| Chili | `SPICE` | 0 | Q1, lawan Spicy 2 | ✅ |
| Garlic | `SPICE` | 0 | Q1, +2 Composure | ✅ |
| Cheese | `DAIRY` | 1 | Q2 | ✅ |
| Cream | `DAIRY` | 1 | Q1, +1 Quality ke bahan lain di Station | ⏳ |
| Stock | `SAUCE` | 0 | Q1 | ✅ |
| Tomato Sauce | `SAUCE` | 1 | Q2 | ✅ |
| Olive Oil | `FAT` | 0 | Q1, +1 Heat giliran berikutnya | ⏳ |
| Sauté | Technique | 1 | +1 Quality untuk semua bahan di Station | ⏳ |
| Flambé | Technique | 2 | 12 Pressure, Hype +10 | ✅ |
| Mise en Place | Technique | 0 | Draw 2 | ✅ |
| Taste Test | Technique | 1 | Lihat 3 kartu teratas, ambil 1 Ingredient | ⏳ |
| Stare Down | Technique | 1 | Lawan Rattled 2 | ✅ |
| Plating Art | Technique | 1 | Serve berikutnya Hype ×2 | ⏳ |
| Second Helping | Technique | 2 | Kembalikan 1 bahan dari Serve terakhir ke tangan | ⏳ |
| Clean Station | Technique | 0 | Buang 1 bahan dari Station, draw 1 | ⏳ |
| Crowd Pleaser | Technique | 1 | Hype +20 | ✅ |

(Quick Chop, Deep Breath, Egg, Bread, Tomato, Butter dari starter deck juga ✅.)

### 6.3 Resep ✅ (13, semuanya ada di `godot/data/recipes`)
| Resep | Buku | Butuh (tag/bahan kunci) | Efek dasar |
|---|---|---|---|
| **Omelette** | Basics | `FAT` → *Egg* → `VEGGIE` | 10 Pressure, 5 Composure |
| **Toast** | Basics | `CARB` → `FAT` | 6 Pressure, draw 1 |
| **Fresh Salad** | Basics | `VEGGIE` → `VEGGIE` | 8 Composure, hapus 1 debuff |
| **Sandwich** *(baru)* | Basics | *Bread* → `PROTEIN` → `VEGGIE` → *Bread* | 12 Pressure, 6 Composure |
| **Classic Steak** | Grill Master | `FAT` → *Beef* → `SPICE` | 20 Pressure |
| **Skewers** | Grill Master | `PROTEIN` → `SPICE` | 8 Pressure, Focus 1 |
| **Mixed Grill** | Grill Master | `FAT` → `PROTEIN` → `PROTEIN` | 16 Pressure, lawan Rattled 1 |
| **Burger** *(baru)* | Grill Master | *Bread* → *Beef* → *Cheese* → `VEGGIE` → *Bread* | 22 Pressure, 6 Composure |
| **Arrabbiata** | Spice Route | `SPICE` → `SAUCE` → `CARB` | 8 Pressure, Spicy 4 |
| **Hot Wings** | Spice Route | *Chicken* → `SPICE` → `SPICE` | 6 Pressure, Spicy 6 |
| **Warm Soup** | Comfort Food | `VEGGIE` → `PROTEIN` → `SAUCE` | Pulihkan 5 Confidence, 8 Composure |
| **Mac & Cheese** | Comfort Food | *Pasta* → `FAT` → `DAIRY` | 8 Pressure, 8 Composure |
| **Mushroom Risotto** | Comfort Food | *Rice* → *Mushroom* → `DAIRY` | 10 Composure, Inspired |

*Semua efek ditambah total Quality di Station, lalu dikali pengali Perfect (×1.5).*

### 6.4 Kitchen Tools (±8) ⏳
Reward run (bukan per duel, beda dari modifier Flow). Perlu dicocokkan dengan Station Stack.
- **Grandma's Pan**: Serve resep pertama tiap duel +5 Pressure.
- **Sharp Santoku**: Technique yang memberi Pressure +2.
- **Bigger Plate**: Station menampung 7 kartu (dari 6).
- **Lucky Apron**: mulai duel dengan Hype 25.
- **Spice Rack**: setiap memainkan `SPICE`, +1 Composure.
- **Butter Dish**: bahan `FAT` +1 Quality.
- **Cast-Iron Lid**: Station yang ditahan ke giliran berikutnya memberi +3 Composure.
- **Food Critic's Pen**: Signature Dish +50%.

### 6.5 Lawan (Market Street)
Skala Confidence mengikuti pemain 100 (fase G, 23 Nov). Angka ✅ sudah dituning dengan `tests/balance.gd`.

| Lawan | Tipe | Confidence | Profil AI | Gimmick | Status |
|---|---|---|---|---|---|
| **Tony**, street noodle cook | Duel | **45** | `greedy`, Heat 2, tangan 4 | Serve begitu ada resep. Lawan tutorial. | ✅ data + model 3D + animasi |
| **Rosa**, taco truck queen | Duel | **50** | `trickster`, Heat 3, tangan 4 | Deck Onion/Stare Down, sering memberi Flustered/Rattled. | ✅ data, ⏳ model 3D |
| **Marco**, pizza showman | Duel | ±42 *(belum dituning)* | `showman` | Menahan stack 2 giliran untuk hidangan besar; mood Confident muncul sebelumnya. Mengajarkan pentingnya Composure. | ⏳ |
| **Élodie**, rival patissière | Elite | ±60 *(skala lama)* | `patient` | Kalau Station pemain berisi ≥ 5 kartu di awal giliran rival, pemain Rattled 1 (membaca *jumlah* kartu, publik). | ⏳ |
| **"Iron" Bruno**, butcher-turned-grill master | Boss | ±110 *(skala lama)*, 2 fase | `boss` | Fase 1: Burnt tiap 2 giliran. Fase 2 (≤50%): Heat +1 dan Focus +1 tiap giliran. | ⏳ |

Hasil balancing (300 duel, deck starter): Tony kalah ±80% dari pemain sederhana (98% dari bot pintar), Rosa 38% / 87%, duel ±4.7–7.5 giliran, rival ±4.2–4.8 aksi per giliran. Detail: [GRAND_DESIGN.md §8.2](GRAND_DESIGN.md). Marco, Élodie, dan Bruno perlu dituning ulang untuk skala 100.

### 6.6 Event (3) ⏳
Pilihan teks singkat dengan portrait. Contohnya: pedagang bahan misterius, kritikus makanan meminta cicip, dan bantu pedagang yang kewalahan.

## 7. Visual & presentasi
Arah visual lengkap, palet 24 warna, pipeline pixel, HUD, emote, announcer, dan daftar aset ada di [ART_DIRECTION.md](ART_DIRECTION.md). Ringkasannya:

- **Diorama pixel hangat:** dunia 3D low-poly dirender ke 640×360 (SubViewport, nearest) lalu di-scale ×3. Filter pixel **on by default** (`P` untuk toggle). Palet "Market Street": kayu, krem, aksen merah/oranye.
- **Kamera fix, sudut tinggi ala diorama.** Dua meja masak berhadapan, rival di kanan, penonton berupa blok siluet.
- **Meja adalah panggung.** HUD terasa fisik (papan kayu, kertas, pita), dengan lencana diamond untuk portrait dan gauge bersegmen untuk Hype.
- **Wajah yang bicara.** Rival bereaksi lewat emote (Smug, Shocked, Angry, Sad, Confident, Wary).
- **Setiap momen punya cap.** Announcer: 3·2·1 → ROUND N → FIGHT! → FINISHED → **YOU WINS!** / **LOSER**.

**Prinsip UX:** semua pilihan berbentuk kartu (encounter, reward, tool, buku resep); state terbaca sekilas (selesai = centang, sekarang = terang berbingkai, terkunci = gelap + gembok); reveal itu momen (overlay, animasi, suara); tooltip keyword di mana-mana.

| Layar | Status |
|---|---|
| Duel (HUD v2, Card v2, Recipe Book v2, Station Stack, Almanac) | ✅ |
| Course Path | ⏳ kartu encounter besar, strip progres |
| Reward / reveal Recipe Book | ⏳ overlay gelap, kartu reveal, "Click anywhere to continue" |
| Pilih kartu / Kitchen Tool | ⏳ 3 pilihan, bingkai tebal, tooltip keyword |
| Tutorial | ⏳ modal berhalaman, muncul kontekstual saat fitur pertama muncul, bisa dibuka ulang |
| Deck & resep viewer | ⏳ read-only (Almanac sudah mencakup sebagian) |

### 7.1 Aset (track fal)
- **3D:** panggung Market Street, MC, 5 chef, dan ±13 model hidangan yang muncul saat Serve. Karakter: GLB dengan rig Mixamo. ✅ **Apis** dan **Tony** (animasi idle, chop, busy, victory, lose). ⏳ Rosa, Marco, Élodie, Bruno, panggung, hidangan. Dibuat lewat image-to-3D di **fal** dari concept art, lalu dirapikan, atau dimodel low-poly sederhana kalau hasilnya kurang.
- **2D:** ilustrasi kartu, ikon modifier, dan portrait dialog dari **fal** / Nano Banana, dengan style reference tetap supaya konsisten. Prompt sheet sudah ada di repo. Ikon SVG putih untuk tag dan status ✅.
- **Animasi minimal per chef:** idle, chop, busy, victory, lose. Kalau rigging terlalu mahal, pakai animasi prosedural.
- **Momen wajib:** cut-in Signature Dish (render 3D close-up + overlay 2D speed lines), reaksi lawan saat Confidence habis, VS screen sebelum Bruno.

## 8. Audio (track ElevenLabs)
- ✅ Autoload `Audio`: musik loop dan SFX dasar sudah terpasang.
- ⏳ **Voice line pendek** tiap chef (taunt, kena Serve besar, menyerah), MC (teriakan Signature Dish), dan announcer cooking show ("SERVE!", "INCREDIBLE!").
- **SFX:** desis wajan, potong, piring, sorakan penonton, cut-in whoosh. Musik: tema duel upbeat dan tema boss.
- Semua audio dibuat saat development dan disimpan sebagai file di build. **Tidak ada API key di game.**

## 9. Arsitektur teknis (Godot 4.7)

```
godot/
  project.godot, export_presets.cfg (preset Web → build/web/index.html)
  data/        Resource .tres, 1 file per item: cards, recipes, enemies, books, decks, modifiers
  scripts/
    data/      class Resource: CardDef, RecipeDef, EffectDef, EnemyDef, AiProfile, BookDef, DeckDef, ModifierDef, StatusDefs
    core/      logika murni, tanpa node: Duel, Kitchen, RecipeMatch, RivalAI, SeededRng, Almanac, CardInstance
    stage/     chef, stage (panggung 3D)
    ui/        duel_ui, card_view, hud, turn_director, announcer, emote_bubble, almanac_view, keywords
    audio/     autoload Audio
  scenes/      main.tscn (node sistem), stage/, ui/duel_ui.tscn (HUD, node unique-name)
  tests/       sim.gd, balance.gd, audio_check.gd, glb_check.gd, ui_drive.gd, chef_drive.gd, hit_probe.gd
```

- **Data-driven:** menambah konten = menambah file `.tres`, bukan menulis logika baru.
- **Logika terpisah dari visual:** `scripts/core/` tidak memakai node. Visual mendengarkan sinyal `Duel` (`card_played(side, …)`, `dish_served(side, …)`, `flow_offer`, dst.), jadi duel bisa disimulasikan headless (`tests/sim.gd`, `tests/balance.gd`).
- **Sistem = node di scene,** bukan di-spawn dari kode. Nilai tuning pakai `@export` supaya terlihat di Inspector.
- **Satu save run** di `user://` (⏳). Almanac sudah punya save sendiri.

**Checklist syarat jam**
- [ ] Build statis Web, `index.html` di root (preset Web sudah ada, belum diuji di browser)
- [ ] Frame pertama < 10 detik, download awal < 50 MB, 45+ fps di 1080p
- [ ] Responsif di 1920×1080, 1366×768, 2560×1440, 3440×1440, 1024×640 (`tests/hit_probe.gd` sudah ada)
- [ ] Tanpa login, iklan, tracking, atau API key di build
- [ ] Sinyal `og:ready` via SDK OpenGame
- [ ] Credit dan cek terms fal & ElevenLabs
- [ ] Bisa dimainkan penuh dengan mouse
- [x] Git sejak hari pertama (bukti riwayat pengembangan)

## 10. Jadwal

| Minggu | Tanggal | Fokus | Milestone | Status |
|---|---|---|---|---|
| 1 | 22–28 Nov | Combat inti, Station Stack, rival AI, RNG, Flow, Almanac, audio dasar, HUD, 2 chef | **Duel penuh bisa dimainkan** | ✅ tercapai lebih cepat (23 Nov) |
| 2 | 29 Nov–5 Des | RunState, Course Path, reward, Shop + Recipe Book, Practice Kitchen, Kitchen Tools, event, save, Marco/Élodie/Bruno, 7 kartu sisa | **Satu run penuh graybox** | ⏳ |
| 3 | 6–12 Des | Aset (panggung, chef, hidangan, kartu), UI final, cut-in, VS screen, voice ElevenLabs, balancing run | **Vertical slice Market Street** | ⏳ |
| 4 | 13–18 Des | Tutorial, juice, tes 5 ukuran window, export Web, **upload pertama 14 Des**, perbaikan dari review. Final paling lambat 17 Des | **Submit** | ⏳ |

**Kalau jadwal mundur, yang dipotong berurutan:** event → Marco → Kitchen Tools 8 → 5 → animasi rig (ganti prosedural) → fase 2 Bruno.

## 11. Perubahan dari versi sebelumnya

| Fitur | Keputusan | Alasan |
|---|---|---|
| Vite + TypeScript + Three.js | **Diganti: Godot 4.7** (22 Nov) | Pipeline pixel 3D, animasi, dan audio lebih mudah. Versi lama tetap di `src/` sebagai referensi |
| Plate 5 slot | **Diganti: Station Stack** | Resep berurutan, bisa menyiapkan dua hidangan, terbaca seperti solitaire |
| 3 Station | **Diganti: 2 Station** (23 Nov) | Layar lebih lega dan duel lebih jelas dibaca |
| Intent lawan | **Diganti: rival drafting** | Lawan bermain dengan aturan yang sama, lebih adil dan lebih hidup |
| "Tanpa hint resep" | **Diubah:** Order Ticket boleh memberi hint | Pemain baru perlu tahu urutan yang benar |
| 3 distrik (Gourmet Avenue, Grand Arena) | **Stretch:** Gourmet Avenue + Madame Céleste kalau run 1 sudah selesai di minggu 3 | Scope 4 minggu |
| Meta-progression (Chef Rank, Kitchen Prep, Challenges) | ✂️ **Dipotong** | Juri bermain 1–2 run. Pengecualian: discovery Almanac (pengetahuan, bukan kekuatan) |
| Secret Seasoning (consumable) | ✂️ **Dipotong** | Sistem tambahan, nilai kecil untuk jam |
| Settings resolusi/fullscreen | **Diganti:** hanya volume | Game berjalan di browser |
| Build Windows / itch.io | **Diganti:** web-only OpenGame | Aturan jam |
| "Tanpa voice acting" | **Diubah:** voice line pendek via ElevenLabs | Track sponsor |

## 12. Pertanyaan terbuka
- [x] ~~Judul~~ → **Finale** (sementara).
- [x] ~~Nama MC~~ → **Apis Tetrarch** (Apis), sementara.
- [x] ~~Pixel filter~~ → **dipakai**, on by default.
- [x] ~~Jumlah Station~~ → **2**.
- [ ] **Juri sebagai modifier per duel** (mis. juri suka pedas: resep `SPICE` +30%)? Kandidat stretch.
- [ ] **Telegraph tanpa Intent cukup?** Mood + jumlah kartu di station rival harus cukup untuk keputusan bertahan. Dicek di playtest pertama; kalau kurang, tambahkan "ready glow" di station rival yang bisa di-Serve.
- [ ] **Skala Confidence Élodie dan Bruno** untuk pemain 100: tuning dengan `tests/balance.gd` saat dibuat.
