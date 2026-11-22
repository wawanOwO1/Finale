# Grand Design — Turn Sequence, Rival AI, RNG, Chef's Flow, Almanac

> Disusun 22 Nov 2026 dari diskusi sesi *gameplay-mechanics-phase-timing*. Dokumen ini **menggantikan GDD §4.6 (Intent lawan)** dan menambah sistem baru di atas Station Stack ([ART_DIRECTION.md §6](ART_DIRECTION.md#6-station-stack--resep-berurutan-usulan-grand-design)).
> Kode yang dirujuk: Godot 4 di `godot/` (`scripts/core/duel.gd`, `scripts/ui/duel_ui.gd`, `scripts/data/enemy_def.gd`).

## 0. Keputusan (22 Nov)

| # | Topik | Keputusan |
|---|---|---|
| 1 | Tempo giliran | Urutan tetap: **YOUR TURN banner → giliran pemain → RIVAL TURN banner → rival drafting (dianimasikan) → loop**, sampai menang/kalah. |
| 2 | Logika vs tempo | `Duel` tetap logika murni. Tempo diatur **Turn Director** di lapisan UI. |
| 3 | Rival | Rival **drafting dengan aturan yang sama** dengan pemain: deck, tangan, Heat, 3 station, Serve. Tidak ada lagi pola Intent. |
| 4 | Informasi | Kartu rival **blind**. Pemain melihat **punggung kartu** di station rival (jumlahnya), animasi, damage, buff/debuff, dan stats. |
| 5 | Intent | Dihapus. Diganti **mood** rival (emote samar). |
| 6 | Almanac | Model **discovered**, bisa dibuka saat duel (game pause). Resep yang disajikan rival ikut tercatat. |
| 7 | Fast-forward | Tahan klik/Space = giliran rival ×3. |
| 8 | Tingkat AI | Rival awal serakah → Elite sabar → Boss dengan gimmick. |
| 9 | RNG | Output **deterministik**. Input random dengan pseudo-random ringan (anti-clump + Mise en Place). AI memakai aturan RNG yang sama. |
| 10 | Power-up | **Chef's Flow**: 2 Perfect Order → pilih 1 dari 3 modifier, threshold naik 2 → 3 → 4, **per duel**, bisa di-stack. |
| 11 | Rival & modifier | Rival juga bisa mendapat modifier (threshold lebih tinggi untuk rival awal), tampil sebagai ikon buff. |
| 12 | Pity diberi tanda | Bad-luck protection **terlihat**: "✨ Mise en place!". |

---

## 1. Turn Sequence

### 1.1 Urutan

```
┌──────────────┐   ┌────────────────┐   ┌────────────────┐   ┌──────────────────────┐
│ YOUR TURN    │ → │ Giliran pemain │ → │ TONY'S TURN    │ → │ Rival drafting       │
│ banner       │   │ (bebas, tanpa  │   │ banner         │   │ (aksi satu per satu, │
│              │   │  batas waktu)  │   │                │   │  kartu tertutup)     │
└──────────────┘   └────────────────┘   └────────────────┘   └──────────────────────┘
        ↑                                                               │
        └───────────────────── loop sampai menang / kalah ──────────────┘
```

Kemenangan/kekalahan bisa memotong urutan di titik mana pun (Spicy tick, Serve, dll). Director langsung pindah ke urutan hasil (ART_DIRECTION §7).

### 1.2 Timing (kecepatan normal)

| Langkah | Isi | Durasi |
|---|---|---|
| **P1** Banner | "YOUR TURN" slam + SFX *Turn change* | 1.0 s |
| **P2** Awal giliran | Composure → 0, Spicy tick (angka melayang), lalu draw (kartu terbang satu per satu, 0.08 s/kartu) | 0.5–1.0 s |
| **P3** Giliran pemain | Input terbuka. Tidak ada timer. | bebas |
| **P4** End Turn | Tangan dibuang (animasi ke discard) | 0.4 s |
| **E1** Banner | "TONY'S TURN" (warna rival) | 1.0 s |
| **E2** Awal giliran rival | Composure → 0, Spicy tick, punggung kartu terbang ke tangan rival | 0.5 s |
| **E3** Aksi rival (loop) | *Think* (bubble "…", 0.35 s) → aksi (lihat 1.3) | 0.6–1.8 s/aksi |
| **E4** Akhir giliran rival | Tangan rival dibuang, jeda | 0.4 s |

Target giliran rival: **4–7 detik** dengan 3–6 aksi. Lebih dari itu terasa lambat bagi juri.

### 1.3 Animasi aksi rival

| Aksi | Yang terlihat | Durasi |
|---|---|---|
| Taruh bahan | Punggung kartu meluncur ke station rival, tumpukan bertambah | 0.5 s |
| Technique | Kartu dibalik sebentar **hanya untuk efeknya** (ikon efek, bukan nama kartu), lalu angka/status melayang | 0.7 s |
| Pindah kartu teratas | Punggung kartu bergeser antar station | 0.4 s |
| Clear station | Tumpukan disapu ke discard | 0.4 s |
| **Serve** | Station rival menyala → **dish reveal** (nama + ikon hidangan, PERFECT/COOKED) → damage ke pemain | 1.8 s |

> Saat Serve, hidangannya **terungkap** (informasi setelah aksi, sama seperti pemain melihat damage). Bahan penyusunnya tetap tidak ditampilkan satu per satu, tapi resepnya tercatat di Almanac (§5).

### 1.4 Fast-forward
- **Tahan klik kiri atau Space** selama fase rival = semua tween ×3, *think* dilewati.
- Banner tetap muncul (diperpendek ke 0.4 s) supaya pemain tidak kehilangan orientasi.
- Toggle "Rival speed: Normal / Fast" di menu volume (opsional, kalau sempat).

### 1.5 Arsitektur

**`Duel` (logika)** mendapat fase `"enemy"` dan API langkah demi langkah:

```gdscript
duel.end_turn()               # P4: buang tangan, phase = "enemy". Tidak lagi memanggil giliran rival.
duel.begin_enemy_turn()       # E2: Composure rival → 0, Spicy tick, antre aksi giliran ini.
duel.enemy_step() -> Dictionary
    # Menerapkan SATU aksi, memancarkan sinyal, lalu mengembalikan { kind, … }.
    # Fase A (pola Intent): "attack" | "block" | "status" | "end". Fase C (AI): "place" | "technique" | "move" | "clear" | "serve" | "end".
    # "end" = E4 (decay akhir giliran rival). enemy_actions_left() = sisa aksi.
duel.start_player_turn()      # P2: phase = "player", Composure, Spicy, draw.
duel.run_enemy_turn()         # loop sinkron untuk tests/sim.gd (tanpa animasi).
```

**`TurnDirector` (UI, `scripts/ui/turn_director.gd`)** memegang urutan 1.1:

```gdscript
func _rival_turn() -> void:
    _lock_input()
    await _banner(rival_name + "'S TURN")
    while duel.phase == "enemy":
        await _think()                      # bubble "…" (dilewati saat fast-forward)
        var a := duel.enemy_step()
        await _play_action(a)               # tween sesuai tabel 1.3
        if a.kind == "end": break
    if duel.phase == "enemy":
        duel.finish_enemy_turn()
        await _banner("YOUR TURN")
        await _deal_hand()
    _unlock_input()
```

- Semua tween lewat satu `speed` global (1.0 normal, 3.0 fast-forward).
- `_busy` yang sudah ada di `duel_ui.gd` dipakai sebagai input lock.
- Intro duel (3·2·1 FIGHT) yang sekarang langsung masuk ke "YOUR TURN" banner.

---

## 2. Kitchen simetris (refactor inti)

Sekarang `Duel` menyimpan tangan, draw pile, station, Hype, dan Heat **hanya untuk pemain**. Rival yang drafting butuh semua itu juga. Refactor:

```gdscript
class Kitchen:              # satu per sisi: duel.kitchen["player"], duel.kitchen["enemy"]
    var fighter: Fighter    # Confidence, Composure, Heat, statuses (sudah ada)
    var draw_pile / hand / discard / exhausted
    var stations            # 3 × Array[CardInstance]
    var recipes             # dari Recipe Book sisi itu
    var hype, flow, flow_threshold_index
    var modifiers: Array[ModifierDef]
    var served_this_turn, moved_this_turn
    var rng_shuffle: SeededRng
```

- `play / serve / move_top / clear_station / can_*` menerima `side` (default `"player"` supaya UI lama tetap jalan).
- `_apply_effects`, `_do_serve`, status, Signature: semuanya berbasis `side`, jadi aturan rival = aturan pemain.
- Sinyal dapat argumen `side`: `card_played(side, card)`, `dish_served(side, …)`, dst.
- `Fighter.heat` sudah ada ("Player only"), sekarang dipakai keduanya.

---

## 3. Rival AI

### 3.1 Data (`EnemyDef` baru)

| Field | Isi | Contoh Tony |
|---|---|---|
| `deck` | `DeckDef` rival | 10 kartu sederhana |
| `books` | Recipe Book yang dikuasai | Basics |
| `max_heat` | Heat per giliran | **2** |
| `hand_size` | Draw per giliran | **4** |
| `profile` | `AiProfile` (3.3) | `greedy` |
| `flow_thresholds` | Threshold Chef's Flow | `[3, 4, 5]` |
| `gimmicks` | Daftar aturan khusus (3.5) | — |

`pattern: Array[IntentDef]` dihapus setelah AI jalan. `IntentDef` dipertahankan sementara hanya untuk fallback saat refactor.

### 3.2 Cara berpikir (satu aksi per `enemy_step`)

1. Kumpulkan **kandidat aksi** yang legal: taruh tiap bahan di tiap station, mainkan Technique, pindah kartu, clear, Serve tiap station, End Turn.
2. Beri **skor** tiap kandidat memakai **preview** logika yang sama dengan pemain (`RecipeMatch`, `preview_serve(side, station)` tanpa menerapkan efek).
3. Ambil skor tertinggi. Skor seri → pakai `rng_ai` (stream terpisah, §4.3).
4. Kalau skor terbaik < `end_threshold` profil atau Heat habis → `End Turn`.

**Rumus skor (garis besar):**

| Kandidat | Skor |
|---|---|
| Serve station s | `pressure_preview × w_attack + composure_preview × w_defend`; **+1000 kalau lethal**; −`w_patience` × nilai resep lebih besar yang tinggal 1 langkah lagi di station itu |
| Taruh bahan | Kemajuan menuju resep terbaik yang bisa dicapai station itu; bonus kalau urutan masih Perfect; penalti kalau merusak resep yang hampir jadi |
| Technique Pressure | `pressure × w_attack` (+ bonus lethal) |
| Technique Composure | `composure × w_defend × danger` |
| Debuff | nilai tetap × `w_debuff` |

`danger` = estimasi ancaman pemain dari **informasi publik saja**: jumlah kartu di station pemain, Hype pemain, Confidence rival sendiri. **AI tidak membaca isi station atau tangan pemain.** Informasinya simetris dengan pemain.

### 3.3 Profil

| Profil | Perilaku | `w_attack` | `w_defend` | `w_patience` | Dipakai |
|---|---|---|---|---|---|
| `greedy` | Serve begitu ada resep cocok, jarang bertahan | 1.0 | 0.3 | 0 | Tony |
| `trickster` | Suka debuff, Serve sedang | 0.8 | 0.5 | 0.2 | Rosa |
| `showman` | Menahan stack untuk hidangan besar, Perfect | 1.0 | 0.6 | 0.8 | Marco |
| `patient` | Perfect Order, bertahan saat Confidence < 40% | 0.9 | 0.9 | 0.6 | Élodie (Elite) |
| `boss` | `patient` + gimmick fase | 1.1 | 0.8 | 0.5 | Bruno |

### 3.4 Mood (pengganti Intent)

Emote yang sudah ada (ART_DIRECTION §5) dipicu dari **niat AI di awal giliran**, bukan dari isi kartu:

| Mood | Pemicu (dari perencanaan AI) | Emote |
|---|---|---|
| Confident | Ada station yang bisa di-Serve ≥ 12 Pressure giliran ini | Kedip `> ●` |
| Wary | AI memilih bertahan (`danger` tinggi) | Mata menyipit, keringat |
| Smug | Confidence pemain ≤ 30% | sudah ada |
| Angry | Confidence rival ≤ 25% | sudah ada |

Mood samar: pemain tahu "akan ada serangan besar", tapi tidak tahu berapa dan dari bahan apa.

### 3.5 Tabel visibilitas

| Informasi | Pemain melihat? |
|---|---|
| Jumlah kartu di tangan rival | ✅ (punggung kartu) |
| Jumlah kartu per station rival | ✅ (tumpukan punggung kartu) |
| Isi kartu di tangan/station rival | ❌ |
| Heat rival (pip) | ✅ |
| Efek Technique rival (ikon + angka) | ✅ saat dimainkan |
| Nama hidangan rival + PERFECT/COOKED | ✅ saat Serve |
| Damage, Composure, buff, debuff, Hype, Chef's Flow, modifier rival | ✅ |
| Mood rival | ✅ |
| Resep yang dikuasai rival | ❌ sampai disajikan (lalu tercatat di Almanac) |

### 3.6 Gimmick lama, diterjemahkan

| Rival | GDD lama | Versi drafting |
|---|---|---|
| Tony | Pola sederhana | `greedy`, Heat 2, tangan 4. Lawan tutorial. |
| Rosa | Sering Taunt | Deck banyak Onion/Stare Down, `trickster`. |
| Marco | Cooking 2 turn | `showman`: menahan stack 2 giliran untuk Mixed Grill/Classic Steak. Mood Confident muncul satu giliran sebelumnya. |
| Élodie | Plate penuh → Rattled | Gimmick: kalau station pemain mana pun berisi ≥ 5 kartu di awal giliran rival, pemain Rattled 1. |
| Bruno | Burnt tiap 2 giliran, Focus fase 2 | Gimmick: Burnt tiap 2 giliran. Fase 2 (≤ 50%): Heat +1 dan Focus +1 per giliran. |

---

## 4. RNG

### 4.1 Peta

| | Input random (sebelum aksi) | Output random (setelah aksi) |
|---|---|---|
| Duel | Shuffle, draw, tie-break AI | **Tidak ada.** Damage, Quality, efek resep, modifier: semuanya pasti. |
| Run | Penawaran modifier, reward kartu, Course Path | Tidak ada |

Prinsip: **apa yang terjadi setelah pemain bertindak selalu bisa dihitung dari tiket dan tooltip.** RNG hanya menentukan "kartu apa yang kamu dapat", bukan "berhasil atau tidak".

### 4.2 Pseudo-random (ringan)

| Aturan | Isi | Berlaku untuk |
|---|---|---|
| **Anti-clump shuffle** | Setelah Fisher–Yates, kalau 4+ Technique berurutan di 5 kartu teratas, shuffle ulang (maks 3 kali, lalu terima apa adanya) | Pemain + rival |
| **Mise en Place** (bad-luck protection) | Setelah draw awal giliran, kalau tangan **tidak berisi satu pun bahan yang bisa ditaruh**, 1 Technique ditukar dengan bahan teratas di draw pile. Maks 1× per giliran. Tampil "✨ Mise en place!" | Pemain + rival |
| **Pity rarity** (penawaran modifier) | 3 penawaran berturut-turut tanpa Rare → penawaran berikutnya dijamin berisi 1 Rare | Pemain |

Tidak ada pity lain. Membentuk peluang adalah tugas deckbuilding (membuang kartu, memilih bahan, memilih buku).

### 4.3 Stream terpisah

Satu seed run → diturunkan ke stream independen:

```
run_seed ─┬─ shuffle_player
          ├─ shuffle_enemy
          ├─ ai_tiebreak
          └─ offers (modifier, reward)
```

Keputusan AI tidak menggeser kartu yang akan didraw pemain. Run tetap bisa direproduksi dari satu seed (debug, sim, daily seed nanti).

### 4.4 Janji fair (ditulis juga di tutorial/credit)
- Rival memakai deck, shuffle, dan aturan pity yang sama.
- Rival tidak melihat tangan dan isi station pemain.
- Draw rival tidak dicurangi berdasarkan kondisi pemain.

---

## 5. Chef's Flow & Modifier

### 5.1 Aturan
- Setiap Serve **Perfect Order** = +1 Flow. Serve Cooked/Improvised = +0.
- Threshold: **2 → 3 → 4** (lalu tetap 4). Saat tercapai, Flow kembali 0 dan muncul **pilih 1 dari 3 modifier**.
- **Per duel**: modifier dan Flow reset di awal duel berikutnya. Kitchen Tool tetap reward run (GDD §6.4).
- Pemain: overlay pilih kartu (ref Gambar 3) muncul **setelah Serve selesai diresolusi**. Game pause.
- Rival: memilih otomatis sesuai profil. Announcer chip **"TONY GOT HOT PAN!"** (1 s) + ikon di baris modifier rival.

| Meter | Naik dari | Hadiah | Sifat |
|---|---|---|---|
| Hype | Serve resep apa pun | Signature Dish | Ledakan sekali pakai |
| **Chef's Flow** | Serve **Perfect Order** | Modifier | Permanen dalam duel, bertumpuk |

### 5.2 Aturan penawaran
1. Tidak ada modifier non-stackable yang sudah dimiliki.
2. Minimal 1 dari 3 **cocok dengan build** (tag dominan di deck atau buku yang dikuasai).
3. Pity rarity (4.2).
4. Komposisi: 2 Common + 1 slot (Common 75% / Rare 25%).

### 5.3 Pool awal (±10)

| Modifier | Rarity | Efek | Stack |
|---|---|---|---|
| Hot Pan | Common | Serve pertama tiap giliran +3 Pressure | +3 per stack |
| Steady Hands | Common | +1 Composure tiap menaruh bahan | +1 |
| Encore | Common | Multiplier Perfect Order ×1.5 → +0.25 | +0.25 |
| Extra Burner | Common | +1 Heat di giliran setelah Serve Perfect | ✗ |
| Prep Cook | Common | Draw +1 di awal giliran | ✗ |
| Crowd Favorite | Common | Hype +10 tiap Serve | +10 |
| Spice Whisperer | Common | Bahan `SPICE` memberi Spicy 1 ke lawan | +1 |
| Free Move | Rare | Pindah kartu teratas 2× per giliran | ✗ |
| Mise Master | Rare | Mise en Place juga aktif kalau tangan punya ≤ 1 bahan | ✗ |
| Plating Pro | Rare | Garnish maks +2 → +4 Quality | ✗ |

### 5.4 Threshold rival

| Rival | Threshold |
|---|---|
| Tony, Rosa | 3 → 4 → 5 |
| Marco | 2 → 4 → 5 |
| Élodie, Bruno | 2 → 3 → 4 (sama dengan pemain) |

---

## 6. Almanac

### 6.1 Isi

| Tab | Entri | Data per entri |
|---|---|---|
| **Ingredients** | Semua bahan (±15) | Tag, Quality, efek, resep yang memakainya |
| **Techniques** | Semua teknik | Biaya, efek |
| **Recipes** | Semua resep (±13) | **Urutan Perfect** (ikon bahan bawah → atas), efek dasar, buku asal, status dikuasai |
| **Rivals** | 5 rival | Portrait, gimmick (terbuka setelah dilawan), resep yang pernah mereka sajikan |
| **Keywords** | Status + Perfect/Cooked/Garnish/Improvised | Teks tooltip yang sudah ada (`keywords.gd`) |

### 6.2 Discovery

| Entri terbuka saat… | |
|---|---|
| Bahan/teknik | Kartunya pernah ada di deckmu, atau ditawarkan sebagai reward/shop |
| Resep | Bukunya kamu kuasai (terbuka penuh), **atau** rival menyajikannya (terbuka, tag "Seen from Tony"), atau bukunya dilihat di Shop |
| Rival | Saat duel dimulai (gimmick terbuka setelah duel selesai) |

Entri yang belum terbuka: siluet + "???" + petunjuk ("Found in Spice Route Journal").

**Persistensi:** discovery disimpan lintas run (`user://almanac.save`). Ini **pengetahuan, bukan kekuatan**, jadi tidak bertentangan dengan keputusan "tanpa meta-progression" (GDD §11).

### 6.3 Combination finder
Di tab Recipes: klik 1–3 ikon tag/bahan → daftar resep yang memakainya, dengan langkah yang masih kurang disorot. Hanya menampilkan resep yang sudah terbuka.

### 6.4 Akses
- Tombol buku (ikon `book.svg`) di HUD + tombol **Tab**.
- Di duel: membuka Almanac **mem-pause** game. Tidak bisa dibuka di tengah animasi giliran rival (antre sampai giliran pemain).
- Di Course Path / Shop: selalu bisa dibuka.

---

## 7. Perubahan HUD

| Elemen | Posisi | Catatan |
|---|---|---|
| Station rival (3 tumpukan punggung kartu) | Meja rival, sejajar station pemain | Tidak bisa di-hover isinya. Tooltip: "3 cards" |
| Tangan rival | Kipas kecil punggung kartu di atas meja rival | Jumlah saja |
| Heat rival | Pip di samping portrait rival | |
| Chef's Flow | Pip kecil (●●○) di bawah bar Hype, per sisi | |
| Baris modifier | Di bawah status, per sisi | Ikon + angka stack, tooltip |
| Mood | Bubble emote yang sudah ada | Menggantikan label Intent |
| Tombol Almanac | Pojok kanan atas, dekat tombol pixel | |
| Banner giliran | Pakai gaya announcer (strip gelap + teks slam) | |

Aset tambahan untuk daftar ART_DIRECTION §8: punggung kartu versi rival (warna rival), 2 emote baru (Wary), ikon modifier ±10, frame Almanac + siluet "???".

---

## 8. Rencana implementasi

| Fase | Isi | Tergantung | Perkiraan |
|---|---|---|---|
| **A. Turn Director** | Fase `"enemy"`, API `enemy_step`, banner, input lock, fast-forward. Rival sementara tetap memakai Intent lewat `enemy_step` | — | 1 hari |
| **B. Kitchen simetris** | Refactor `Duel` ke `Kitchen` per sisi, sinyal dengan `side`, `sim.gd` tetap hijau | A | 1–1.5 hari |
| **C. Rival AI** | `AiProfile`, skor kandidat, `preview_serve`, deck/buku rival, visual station tertutup, mood | B | 2 hari |
| **D. RNG** | Stream terpisah, anti-clump, Mise en Place + tanda | B | 0.5 hari |
| **E. Chef's Flow** | Meter, overlay pilih 3, pool modifier, AI memilih | B (C untuk rival) | 1.5 hari |
| **F. Almanac** | Data dari `GameDB`, discovery + save, UI tab, combination finder | — (paralel) | 1.5 hari |
| **G. Balancing** | `sim.gd`: AI vs AI ratusan duel per rival, cek panjang duel & win rate | C, D, E | 1 hari |

Total ±9 hari kerja, masuk ke minggu 2 jadwal GDD §10 (29 Nov–5 Des) dengan sebagian ke minggu 3. **F bisa dikerjakan paralel** sejak awal.

**Kalau jadwal mundur, potong berurutan:** combination finder → threshold Flow rival → profil `trickster`/`showman` (pakai `greedy`/`patient`) → tab Rivals di Almanac → modifier Rare.

### 8.1 Tes
- `tests/sim.gd`: `run_enemy_turn()` sinkron; duel deterministik untuk seed yang sama (snapshot hasil).
- Tes visibilitas: UI tidak pernah membuat `CardView` berisi kartu rival (hanya punggung).
- Tes fair: dua run dengan seed sama, keputusan pemain berbeda → urutan draw pemain tetap sama (stream terpisah).
- Target balancing awal: Tony kalah dari deck starter ±80% (di tangan AI pemain sederhana), duel 5–8 giliran.

---

## 9. Risiko & pertanyaan terbuka
- [ ] **Panjang giliran rival.** Kalau rival rata-rata > 6 aksi, giliran terasa lama. Mitigasi: Heat rival kecil, gabungkan "taruh 2 bahan" jadi satu animasi.
- [ ] **AI terlalu pintar/bodoh.** Bobot profil perlu dituning lewat sim (fase G).
- [ ] **Hilangnya telegraph.** Mood + jumlah kartu di station rival harus cukup untuk keputusan bertahan. Dicek di playtest pertama; kalau kurang, tambahkan "ready glow" pada station rival yang bisa di-Serve.
- [ ] **Élodie & station pemain.** Gimmicknya membaca *jumlah* kartu station pemain (publik), jadi tetap sesuai janji fair.
