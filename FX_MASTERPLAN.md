# FINALE — FX, Impact Frame & Cutscene Masterplan (v0.1)

> Dokumen pendamping [GDD.md](GDD.md) §4.5, [ART_DIRECTION.md](ART_DIRECTION.md) §1 pilar 4 + §7, dan
> [GRAND_DESIGN.md](GRAND_DESIGN.md) §1. Dibuat 24 Nov 2026.
> Fokus: **"lebay ala anime masak"** tapi tetap **60 fps di browser** (export Web, renderer Compatibility / WebGL2).

---

## 0. Ringkasan satu paragraf

Semua FX dipicu dari **signal `Duel`** (logika tidak tahu apa-apa soal FX), lewat satu node baru **`FxDirector`**
di `main.tscn`. Setiap momen game dipetakan ke **`FxCue`** (Resource `.tres`, bisa diatur di Inspector) dengan
**tier T0–T3**. Tier menentukan anggaran: berapa lama hitstop, seberapa kuat shake, boleh flash atau tidak,
berapa partikel. Efek layar penuh (flash, impact frame, chromatic, desaturasi) **digabung ke shader post yang
sudah ada** (`pixel_post.gdshader`) lewat beberapa uniform, jadi tidak menambah pass. Cutscene dibuat
**real-time di engine** (AnimationPlayer + kamera kedua + overlay 2D), **bukan video**.

---

## 1. Pilar FX

1. **Jelas dulu, baru heboh.** FX tidak boleh menutupi angka Pressure, kartu, atau tiket. Puncak efek ≤ 0.3 s, lalu UI kembali terbaca.
2. **Berjenjang.** Tidak semua aksi meledak. Kalau semua T3, tidak ada yang terasa T3. Mayoritas aksi = T0/T1.
3. **Diam sebelum ledakan.** Anime impact = *anticipation → freeze → release*. Hitstop dan 1–3 frame "impact frame" lebih kuat dari partikel banyak.
4. **Murah di GPU.** Satu pass post-process, partikel kecil dan sedikit, tekstur di atlas, tanpa video.
5. **Bisa dipercepat dan di-skip.** Fast-forward rival (×3) dan klik untuk skip cutscene harus selalu jalan.
6. **Aman.** Opsi *Reduce Flashing* dan *Screen Shake* di menu. Flash putih penuh maksimal 3× per detik.

---

## 2. Batasan teknis Web (yang membentuk semua keputusan)

| Batasan | Dampak ke FX | Keputusan |
|---|---|---|
| **Compatibility renderer (WebGL2)** | Tidak ada compute shader, glow/SSAO/SSR terbatas, tidak ada normal buffer | Tanpa `Environment.glow`. "Bloom" palsu = sprite additive. Efek layar lewat `screen_texture` + `depth_texture` di shader post yang sudah ada |
| **`thread_support=false`** (export single-thread, supaya jalan tanpa header COOP/COEP) | Semua GDScript, audio mix, dan render di satu thread | Hindari logika berat di `_process`. Partikel di GPU, bukan loop GDScript. Jangan instansiasi scene di tengah hit |
| **Kompilasi shader saat pertama dipakai** | Di WebGL, shader/material baru menyebabkan *stutter* 50–300 ms tepat saat efek muncul pertama kali (paling parah di Signature) | **Prewarm**: semua material FX dirender 1 frame di luar layar saat loading (lihat §7.1) |
| **Fill-rate GPU laptop (iGPU)** | Sprite besar transparan yang bertumpuk (overdraw) lebih mahal dari jumlah partikel | Partikel kecil. Overlay layar penuh maksimal 2 lapis sekaligus |
| **Ukuran unduhan** | Video, audio WAV, dan PNG besar memperlambat load awal | Tanpa video. Audio `.ogg`. Tekstur FX di 1–2 atlas kecil (pixel art 640×360 grid) |
| **Browser tab di background / perangkat lemah** | Frame time tidak stabil | Semua FX berbasis waktu (detik), bukan frame. Ada **FX Quality: Low** otomatis jika rata-rata FPS < 45 selama 3 s |

### 2.1 Anggaran performa (target)

| Metrik | Target | Batas keras |
|---|---|---|
| FPS di Chrome, laptop iGPU (Intel Iris Xe kelas) | 60 | ≥ 45 |
| Pass layar penuh aktif | 1 (pixel_post) | 2 (saat cutscene) |
| Partikel hidup bersamaan | ≤ 150 | 300 |
| Emitter aktif bersamaan | ≤ 6 | 10 |
| Draw call (2D + 3D) | ≤ 150 | 250 |
| Tekstur FX total | ≤ 2 MB (VRAM) | 4 MB |
| Stutter saat FX pertama kali | 0 | < 16 ms |

### 2.2 Catatan dari kode yang ada

- `StageViewport` sudah diperkecil saat pixel filter menyala (`Main.pixel_height = 270`, lewat `stretch_shrink`,
  MSAA dimatikan). Hanya mode tanpa filter (tombol P) yang render 3D penuh 1080p + MSAA 2×. Untuk build Web,
  pertimbangkan filter selalu menyala, atau shrink ×2 juga saat filter mati.
- `TurnDirector._process` **menimpa `Engine.time_scale` setiap frame** (fast-forward). Hitstop yang memakai
  `Engine.time_scale` akan langsung dibatalkan. Solusi: `FxDirector` menjadi **satu-satunya pemilik time scale**
  (lihat §4.2), TurnDirector hanya meminta faktor fast-forward.
- Sudah ada: shake posisi chef (`Stage._shake`), cut-in Signature (`DuelUI._play_cutin`, shader `CutInRays`),
  announcer slam, angka melayang (`_float`), emote. Masterplan ini **membungkus dan menaikkan** yang ada, bukan mengganti.

---

## 3. Taksonomi momen → tier

### 3.1 Definisi tier

| Tier | Rasa | Hitstop | Shake | Flash / Impact frame | Partikel | Kamera | Durasi total |
|---|---|---|---|---|---|---|---|
| **T0 Micro** | "klik yang enak" | — | — | — | ≤ 8 | — | 0.1–0.25 s |
| **T1 Hit** | pukulan biasa | 40–60 ms | trauma 0.25 | — | ≤ 24 | — | 0.3–0.5 s |
| **T2 Big** | "WOAH" | 80–120 ms | trauma 0.5 | flash tipis (α ≤ 0.35) | ≤ 60 | punch zoom 3% | 0.6–0.9 s |
| **T3 Finisher** | momen anime | 150–250 ms | trauma 0.8 | **impact frame 2–3 frame** | ≤ 120 | cut ke kamera close-up | 1.5–3 s (cutscene) |

### 3.2 Peta signal `Duel` → cue

| Signal / momen | Kondisi | Tier | Isi efek |
|---|---|---|---|
| `card_played` (bahan ke station) | selalu | T0 | Kartu "thunk" (squash 0.9→1.05→1), debu kecil + remah warna tag, tick SFX |
| `card_played` (teknik) | selalu | T0 | Sapuan garis cepat dari kartu ke target, ikon teknik pop |
| Order Ticket step benar | urutan cocok | T0 | Stamp kecil di tiket, kilau 1 frame |
| `status_applied` | Spicy/Flustered/dll. | T0 | Ikon status jatuh ke chef + puff warna status |
| `composure_gained` | > 0 | T0 | Kilau perisai di bar |
| `dish_served` / `dish_revealed` | Cooked / Improvised | T1 | Uap + piring "clang", angka Pressure terbang, hitstop pendek, chef target flinch |
| `dish_revealed` | **Perfect** atau Pressure ≥ 15 | T2 | + flash tipis, speed-line pendek, punch zoom, emote Shocked, crowd melompat serentak |
| `dish_revealed` | **Burnt** | T1 (varian) | Asap hitam, layar sedikit desaturasi 0.3 s, SFX "fssh" turun |
| `confidence_lost` | amount ≥ 25% max | T2 | Bar Confidence retak (crack sprite), chromatic offset singkat |
| `signature_ready` | Hype penuh | T1 | Pita Hype emas menyala, aura muncul di Apis (loop murah) |
| `signature_served` | Apis | **T3** | **Cutscene Signature** (§6.2) |
| `duel_ended` | menang / kalah | **T3** | **Cutscene Finish** (§6.3), lalu announcer yang sudah ada |
| `flow_offer` / `modifier_gained` | | T0/T1 | Kartu modifier berputar masuk, kilau ungu |
| Mulai duel | | T2 | Intro VS (§6.1) sebelum 3·2·1 |
| Fase boss (Bruno) | stretch | T3 | Cutscene pendek "phase 2" |

> **Aturan anti-banjir:** kalau beberapa cue jatuh di frame yang sama (Serve memicu `dish_served` + `pressure_dealt` +
> `confidence_lost`), `FxDirector` **mengambil tier tertinggi** untuk hitstop/shake/flash, dan sisanya hanya
> menjalankan bagian lokal (angka, partikel kecil). Hitstop tidak menumpuk.

---

## 4. Arsitektur

Mengikuti konvensi project (CLAUDE.md): sistem = **node di scene**, nilai tunable = `@export`, `scripts/core/` tetap murni.

```
main.tscn
├─ StageView/StageViewport/Stage
│   ├─ Camera3D                 (kamera duel, sudah ada)
│   │   └─ PixelPost            (shader post: + uniform FX, §5.1)
│   ├─ CutCamera                (BARU: Camera3D close-up, nonaktif default)
│   ├─ CutMarkers/…             (BARU: Marker3D posisi kamera per cutscene)
│   └─ FxPool3D                 (BARU: emitter 3D yang dipakai ulang)
├─ DuelUI
│   └─ %FxLayer (CanvasLayer)   (BARU: speed lines, impact frame 2D, flash, partikel 2D, letterbox)
├─ FxDirector                   (BARU: script fx_director.gd)
│   ├─ HitStop                  (node anak: pemilik time scale)
│   ├─ Shake                    (trauma → offset kamera 3D + offset Root UI)
│   └─ CutscenePlayer           (AnimationPlayer + scene cutscene)
├─ TurnDirector                 (minta fast-forward ke HitStop, tidak set time_scale sendiri)
└─ AlmanacKeeper
```

### 4.1 `FxCue` (Resource, `scripts/data/fx_cue.gd`, file di `data/fx/*.tres`)

```gdscript
class_name FxCue extends Resource
@export var id: StringName
@export_enum("T0", "T1", "T2", "T3") var tier := 0
@export var hitstop := 0.0              # detik
@export var trauma := 0.0               # 0..1, shake
@export var flash := 0.0                # 0..1 alpha puncak
@export var flash_color := Color.WHITE
@export var impact_frame := 0           # jumlah frame (0 = tidak)
@export var zoom_punch := 0.0           # 0.03 = 3%
@export var particles: Array[StringName] = []   # id emitter di pool
@export var sfx: StringName
@export var cutscene: PackedScene       # hanya T3
```

Desainer (kamu) mengatur rasa di Inspector tanpa menyentuh kode. Satu file per momen: `serve_cooked.tres`,
`serve_perfect.tres`, `serve_burnt.tres`, `signature.tres`, `ko_win.tres`, dst.

### 4.2 Time scale: satu pemilik

```
Engine.time_scale = fast_forward_factor × hitstop_factor × cutscene_factor
```

- `HitStop.request(seconds)`: `hitstop_factor = 0.02` selama `seconds` **waktu nyata** (`Time.get_ticks_msec`, bukan delta), lalu kembali 1.
- `TurnDirector` memanggil `HitStop.set_fast_forward(3.0 / 1.0)` daripada menulis `Engine.time_scale`.
- Tween UI yang harus tetap jalan saat hitstop (mis. flash) memakai `set_ignore_time_scale(true)`.

### 4.3 Shake berbasis trauma

- `trauma` 0..1, turun linear ~1.5/s. Offset = `trauma²` × amplitudo × noise (`FastNoiseLite` 1D, sudah built-in, murah).
- 3D: `Camera3D.h_offset / v_offset` (tidak menggeser transform, jadi tidak merusak `_fit_camera` dan `screen_pos`).
- 2D: geser `%Root` beberapa pixel **dibulatkan ke grid 3 px** (pixel art 640×360 ×3) supaya tidak blur.
- Shake chef yang sudah ada (`Stage._shake`) tetap; itu reaksi karakter, bukan kamera.

### 4.4 Pooling

- Semua emitter dibuat **di scene sejak awal** (`FxPool3D`, `%FxLayer`), dipakai ulang dengan `restart()` + pindah posisi.
- Tidak ada `instantiate()` saat hit. Angka melayang (`_float`) juga sebaiknya dipool (sekarang membuat node baru tiap angka).

---

## 5. Teknik efek (resep murah)

### 5.1 Efek layar penuh

> **Keputusan F0:** flash dan desaturasi **tidak** dimasukkan ke `pixel_post`, tapi ke overlay `%FxScreen`
> (`fx_screen.gdshader`, ColorRect di atas HUD). Alasannya: `pixel_post` hanya aktif saat filter pixel menyala
> dan hanya mengenai dunia 3D, sementara flash harus menutup HUD juga. Overlay ini `visible = false` saat
> nilainya 0, jadi biaya salinan layarnya hanya ada selama efek berjalan. Efek yang memang khusus dunia 3D
> (impact frame berbasis depth, `fx_zoom`) tetap direncanakan di `pixel_post` (F2).

Rencana awal (uniform di `pixel_post.gdshader`):

Shader post sudah membaca `screen_texture` dan `depth_texture` di Compatibility. Tambahkan:

| Uniform | Efek | Biaya |
|---|---|---|
| `fx_flash` (float) + `fx_flash_color` | Mix warna ke flash | ~0 |
| `fx_impact` (float 0/1) | **Impact frame**: luminansi → 2 warna (tinta `#1a0f08` / krem) dengan threshold, opsional invert | ~0 |
| `fx_chroma` (float px) | Geser kanal R/B ke arah keluar dari tengah | 2 sample tambahan, hanya saat > 0 (branch uniform) |
| `fx_desat` (float) | Desaturasi (Burnt, kalah) | ~0 |
| `fx_zoom` (float) + `fx_center` | Punch zoom: skala UV dari titik target | ~0 |
| `fx_radial` (float) | Radial blur murah, **4 tap** saja, khusus T3 | 4 sample, hanya saat > 0 |

Karena ini satu shader, **tidak ada kompilasi baru di tengah game** dan tidak ada render target tambahan.
Catatan: post ini hanya mengenai dunia 3D. Untuk HUD, flash/impact dilakukan juga di `%FxLayer` (ColorRect + shader kecil yang sama).

### 5.2 Impact frame (gaya anime)

> **Keputusan F2:** warna **tinta/krem** (`#3b2414` / `#fbf3e2`, palet ART_DIRECTION). Dikerjakan di `fx_screen.gdshader`
> (ambang kecerahan seluruh layar, termasuk HUD), bukan berbasis depth di `pixel_post`: satu shader, jalan dengan atau
> tanpa filter pixel. Siluet karakter putih dan ilustrasi pre-drawn (frame 2 di tabel bawah) belum dibuat.

Urutan T3 (60 fps):

| Frame | Isi |
|---|---|
| 0 | Hitstop mulai. `fx_impact = 1` (dunia jadi siluet hitam-krem). Di `%FxLayer`: speed lines radial hitam penuh + siluet karakter putih |
| 1 | Sama, invert (krem ↔ tinta) — "kedip" khas anime |
| 2 | (opsional) frame ilustrasi **pre-drawn** 640×360, 1 per Signature |
| 3+ | `fx_impact = 0`, flash putih α 0.6 → 0 dalam 0.15 s, shake trauma 0.8, partikel meledak, angka besar slam |

- Versi **Reduce Flashing**: lewati frame 1 (invert) dan flash; pakai desaturasi + speed lines saja.
- Impact frame diatur berdasarkan **waktu nyata** (`impact_frame × 1/60 s`), bukan jumlah frame render, supaya sama di 30 dan 144 Hz.

### 5.3 Speed lines & rays

- Sudah ada shader `CutInRays`. Jadikan satu **shader procedural serbaguna** (`fx_lines.gdshader`): mode radial (fokus), mode horizontal (dash), mode konsentris (shockwave). Semua procedural, **tanpa tekstur**.
- Satu `ColorRect` layar penuh di `%FxLayer`, `visible = false` saat tidak dipakai (tidak ada biaya saat hidden).

### 5.4 Partikel

| Kebutuhan | Pilihan | Alasan |
|---|---|---|
| Remah, uap, puff (2D di atas HUD) | `GPUParticles2D`, 8–40 partikel, tekstur atlas 8×8 / 16×16 | Murah di GPU, tidak membebani GDScript |
| Uap/asap di meja 3D | `GPUParticles3D` dengan **quad billboard** + material unshaded | Kelihatan pixel karena viewport low-res |
| Burst sangat kecil (≤ 6) | `CPUParticles2D` | Tidak perlu shader baru; aman kalau GPU particles bermasalah di driver tertentu |
| Dilarang | Sub-emitter, trail, collision, attractor, turbulence | Mahal atau tidak didukung penuh di Compatibility |

Semua partikel: `one_shot`, `explosiveness` tinggi, `lifetime` ≤ 0.8 s, `fixed_fps = 30` (cukup untuk gaya pixel, separuh biaya).

> **Keputusan F1:** partikel HUD memakai **`CPUParticles2D`**, bukan GPU. Dengan 12–20 partikel per burst biaya CPU-nya
> kecil sekali, dan tidak ada shader partikel yang harus dikompilasi WebGL saat Serve pertama. Tanpa tekstur:
> tiap partikel kotak pixel yang di-scale (cocok dengan gaya pixel, tidak ada atlas untuk diunduh). Atlas tetap
> opsional kalau nanti butuh bentuk (bintang, api).

### 5.5 "Bloom" dan aura tanpa glow

- Aura Signature: 2 sprite additive (lingkaran lembut + api flipbook 4 frame) di belakang Apis, bukan `Environment.glow`.
- Kilau kartu/emas: shader `CanvasItem` dengan pita diagonal yang bergerak (procedural, sudah mirip `_pulse`).

### 5.6 Angka & teks

- Angka Pressure: pop besar → tahan → jatuh, warna sesuai tier. T2/T3 memakai **slam** yang sama dengan announcer.
- Teks SFX ala manga ("SIZZLE!", "CHOP!", "BAM!") sebagai Label dengan outline tinta, 1 font, dipool. Murah dan sangat "anime".

---

## 6. Cutscene

### 6.1 Prinsip

- **Real-time di engine, bukan video.** Godot hanya memutar Theora `.ogv`; di web itu decode di CPU single-thread, berat, dan file besar. Real-time juga otomatis cocok dengan karakter/hidangan yang sedang dipakai.
- **Satu scene per cutscene**, dimainkan oleh `CutscenePlayer` (`AnimationPlayer`) dengan track: kamera (`CutCamera` transform/FOV), visibilitas node, method call (`chef.perform("victory")`, `Audio.sfx`, `FxDirector.impact()`), properti UI di `%FxLayer`.
- **Selalu bisa di-skip** (klik / Space / Esc). Skip = loncat ke frame akhir, state duel tidak tergantung cutscene.
- **Pendek.** Juri jam bermain 1–2 run; Signature yang sama akan terlihat beberapa kali. Versi panjang hanya **sekali per run**, berikutnya versi pendek (≤ 1.2 s).
- **Letterbox** (2 ColorRect hitam masuk dari atas/bawah) = sinyal "cutscene" yang murah dan efektif.

### 6.2 Signature Dish (T3, ±2.5 s penuh / ±1.2 s pendek)

| t (s) | Kamera / dunia | Overlay 2D | Audio |
|---|---|---|---|
| 0.00 | Hitstop, dunia desaturasi, letterbox masuk | Speed lines radial, teks "SIGNATURE!" slam | whoosh |
| 0.25 | Cut ke `CutCamera` close-up Apis (low angle), aura menyala | Panel cut-in miring (bar yang sudah ada) dengan nama hidangan | voice line Apis |
| 0.90 | Apis `perform("chop")` dipercepat, partikel api/uap | Teks manga "SLASH! SLASH!" | chop ×3 |
| 1.40 | **Impact frame** (§5.2) | Siluet hitam-krem | hit berat |
| 1.55 | Cut kembali ke kamera duel, hidangan muncul di meja, rival flinch + Shocked | Angka Pressure ×2 slam, flash | crowd roar |
| 2.30 | Letterbox keluar, kontrol kembali | — | — |

Versi pendek: lompati 0.25–0.90 (close-up), langsung ke impact frame.

### 6.3 Finish / KO (T3, ±2 s, lalu announcer yang sudah ada)

- **Menang:** hitstop panjang 0.25 s pada Serve terakhir → impact frame → slow-mo (`cutscene_factor = 0.3`) 0.6 s sambil kamera dorong pelan ke rival → rival `perform("lose")` → time scale normal → `FINISHED` → `YOU WINS!` (Announcer).
- **Kalah:** tanpa impact frame. Desaturasi bertahap, kamera turun pelan ke Apis berlutut, crowd diam (berhenti bob). Lalu `LOSER` yang sudah ada.

### 6.4 Intro VS (T2, ±2 s, sebelum 3·2·1)

- Split-screen diagonal di `%FxLayer`: kiri Apis, kanan rival. Pakai **potret 2D pre-render** dari model 3D
  (1 PNG per chef, dibuat sekali), bukan render live ke SubViewport tambahan: tidak ada pass 3D ekstra.
- Nama chef slam, "VS" berputar, garis horizontal bergerak. Semua 2D, biaya hampir nol.

### 6.5 Stretch

- Bruno fase 2: kamera berputar 180° di sekitar meja (Marker3D path), lampu `Sun` berubah merah.
- Crowd "wave" (fase sinus per kolom) saat Hype penuh.

---

## 7. Checklist optimasi Web

### 7.1 Prewarm shader & material (wajib)
- Saat loading (di belakang layar cookbook / sebelum 3·2·1): tampilkan **semua** material FX, partikel (`restart()` + 1 frame), shader `fx_lines`, dan set setiap uniform `fx_*` ke nilai > 0 selama 1 frame di bawah overlay hitam.
- Tujuannya agar WebGL mengompilasi semua varian sebelum momen penting. Tanpa ini, Signature pertama akan patah-patah.

### 7.2 Lain-lain
- [ ] StageViewport ke 640×360 (atau 960×540 sebagai kompromi), `msaa_3d` off.
- [ ] `render_target_update_mode`: viewport 3D yang tidak terlihat (CutCamera tidak dipakai) **tidak** di-render. Pakai satu viewport dan ganti `current` kamera, jangan dua viewport.
- [ ] Tekstur FX: satu atlas, filter `nearest`, tanpa mipmap.
- [ ] Semua node FX `visible = false` saat idle (CanvasItem hidden tidak digambar).
- [ ] Partikel `fixed_fps = 30`, `one_shot`, `local_coords` sesuai kebutuhan.
- [ ] Tidak ada `instantiate()`, `load()`, atau `new()` node di jalur hit. `preload` semua.
- [ ] Audio FX `.ogg` mono, pendek. Voice line di-preload sebelum Signature tersedia.
- [ ] Overlay debug **F3**: FPS, `Performance.TIME_PROCESS`, draw calls, partikel aktif. Dipakai saat tes build Web.
- [ ] **FX Quality Low** (otomatis atau manual): partikel ×0.5, `fx_chroma`/`fx_radial` off, cutscene versi pendek, crowd tidak bob.
- [ ] Tes di build Web sungguhan (bukan editor): Chrome + Firefox, laptop iGPU, tab 1600×900 dan 1280×720.

---

## 8. Aset yang dibutuhkan

| Aset | Jumlah | Format | Sumber |
|---|---|---|---|
| Atlas partikel (remah per tag, uap, asap, bintang, percikan, api 4 frame) | 1 atlas 128×128 | PNG, nearest | Gambar tangan / Nano Banana lalu dibersihkan ke palet 24 warna |
| Crack bar Confidence | 3 tahap | PNG kecil | Gambar tangan |
| Potret VS (Apis, Tony, Rosa, Marco, Élodie, Bruno) | 6 | PNG 320×360 | Render model 3D + pixel filter, tangkap layar |
| Ilustrasi impact frame Signature (opsional) | 1–2 | PNG 640×360, 2 warna | Gambar tangan |
| Font teks manga SFX | 1 | font pixel tebal | Sudah ada theme, cek apakah cukup |
| SFX: whoosh, hit berat, clang, sizzle, crowd roar/gasp, glass crack | ±8 | OGG | ElevenLabs SFX |
| Voice: Signature shout Apis, KO line per rival | 1 + 6 | OGG | ElevenLabs |

Shader (semua procedural, tanpa tekstur): `pixel_post` (diperluas), `fx_lines`, `fx_shine`, `fx_flash_ui`.

---

## 9. Roadmap

Diurutkan dari **dampak terbesar per jam kerja**. Setiap fase selesai = commit + tes + merge ke `main` (CLAUDE.md).

| Fase | Isi | Perkiraan | Hasil yang terlihat |
|---|---|---|---|
| **F0 Fondasi** ✅ | `FxDirector` + `HitStop` (pemilik time scale, TurnDirector disesuaikan) + `Shake` trauma + `FxCue` resource + uniform flash/desat di `pixel_post` + prewarm | 1 hari | Serve terasa "berat" walau tanpa partikel |
| **F1 Juice T0–T2** ✅ | Partikel pool (remah, uap, asap), angka slam per tier, punch zoom, teks manga SFX, crack bar, crowd lompat serentak | 1–1.5 hari | Setiap aksi punya umpan balik, Perfect terasa beda dari Cooked |
| **F2 Impact frame** ✅ | `fx_impact`, `fx_chroma`, `fx_lines` serbaguna, versi Reduce Flashing | 0.5 hari | Momen "anime" pertama |
| **F3 Cutscene Signature** | `CutCamera`, `CutscenePlayer`, letterbox, versi panjang + pendek, skip | 1–1.5 hari | GDD §4.5 terpenuhi |
| **F4 Finish + Intro VS** | KO win/lose, VS screen 2D | 1 hari | Awal dan akhir duel terasa seperti acara TV |
| **F5 Optimasi & QA** | Viewport 640×360, overlay F3, FX Quality Low, tes build Web 2 browser | 0.5–1 hari | ≥ 45 fps di iGPU |
| **Stretch** | Bruno fase 2, crowd wave, ilustrasi impact frame pre-drawn | — | — |

> F5 sebaiknya dikerjakan sebagian **sebelum F1** (viewport + overlay F3), supaya semua FX dinilai di kondisi akhir.

**Urutan potong kalau mundur:** Stretch → Intro VS (pakai banner teks saja) → versi panjang cutscene Signature
(pakai versi pendek saja) → `fx_radial`/`fx_chroma` → teks manga. **Jangan dipotong:** hitstop, shake, impact frame,
prewarm. Itu yang paling murah dan paling terasa.

---

## 10. Tes

| Tes | Jenis | Isi |
|---|---|---|
| `tests/fx_check.gd` (baru) | headless | Semua `data/fx/*.tres` valid, tier ↔ anggaran (mis. T0 tidak boleh punya flash), setiap signal `Duel` di §3.2 punya cue |
| `tests/fx_drive.gd` (baru) | window | Mainkan Serve Cooked / Perfect / Signature / KO, simpan screenshot di frame impact, ukur frame time maksimum (gagal jika ada frame > 50 ms setelah prewarm) |
| `tests/ui_drive.gd` (ada) | window | Pastikan FX tidak menghalangi drag/klik (FxLayer `mouse_filter = IGNORE`) |
| `tests/hit_probe.gd` (ada) | window | Shake UI tidak menggeser area klik secara permanen |

---

## 11. Pertanyaan terbuka

- [ ] Impact frame: **2 warna (tinta/krem)** sesuai palet, atau **hitam-putih murni** ala manga? Usulan: tinta/krem, lebih menyatu dengan ART_DIRECTION.
- [ ] Rival boleh punya mini cut-in (T2) saat Serve besar, atau Signature tetap eksklusif Apis secara visual juga?
- [ ] Voice line: berapa yang realistis dari ElevenLabs sebelum 13 Des?
- [ ] Cutscene panjang "sekali per run" atau "sekali per duel"?
