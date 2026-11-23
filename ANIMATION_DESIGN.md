# ANIMATION_DESIGN — Apis & Tony

Rencana animasi untuk dua karakter 3D pertama (`apis.glb`, `tony.glb`). Dibuat di Blender di atas skeleton Mixamo
yang sudah ada, lalu diekspor ulang ke Godot. Dokumen ini menggantikan daftar sementara di CHARACTER_PLAN §6.3
khusus untuk Apis dan Tony.

## 1. Keputusan utama

| # | Topik | Keputusan |
|---|---|---|
| 1 | Daftar clip | **5 clip** per karakter: `idle`, `chop`, `busy`, `victory`, `lose`. Nama sama persis untuk semua chef supaya `chef.gd` cukup memanggil `play("idle")`. |
| 2 | Rig | Skeleton Mixamo bawaan (53 bone `mixamorig:*`). Tidak ada rig ulang, tidak ada IK. Key **rotasi** per bone, ditambah **posisi Hips** untuk bob/lompat. |
| 3 | In-place | Semua clip **di tempat**. Hips hanya naik-turun (Y) dan geser kecil (≤ 3 cm). Chef tidak berjalan; posisi di panggung diatur scene. |
| 4 | Gaya | Chibi, cartoony: pose tegas, **anticipation → aksi → hold**, ease in/out, sedikit overshoot. Gerakan harus terbaca di 640×360, jadi amplitudo dibuat lebih besar dari realistis. |
| 5 | Satu sumber, dua kepribadian | Satu script pose di Blender membuat kelima clip dari tabel pose. Tiap karakter punya **parameter gaya** (tempo, amplitudo, pose khusus), jadi Apis dan Tony terasa beda tanpa animasi manual dua kali. |
| 6 | Frame rate | **30 fps**. Key pose di frame genap, interpolasi Bezier. |
| 7 | Loop | `idle`, `chop`, `busy` = loop mulus (frame terakhir = frame pertama). `victory`, `lose` = sekali main, berhenti di pose akhir (Godot tetap di frame terakhir). |
| 8 | Props | Tidak ada pisau/talenan/wajan di GLB. Pose tangan disiapkan untuk memegang pisau di **tangan kanan**. Props nanti lewat `BoneAttachment3D` di `mixamorig_RightHand`. |

## 2. Kepribadian

| | Apis (MC, underdog) | Tony (street noodle cook, santai, sombong) |
|---|---|---|
| Postur dasar | Tegak, bahu sedikit maju, siap kerja | Agak membungkuk, perut maju, bahu turun |
| Tempo | Normal, cepat saat bekerja | Lebih lambat di `idle`, tapi pamer cepat di `chop` |
| Amplitudo | Sedang, rapi | Besar, longgar, "flashy" |
| Ciri khas | Kepala sering melirik ke tangan (fokus) | Kepala miring, satu tangan di pinggang saat santai |

## 3. Clip

Sisi "kiri/kanan" = sisi tubuh karakter. Durasi untuk Apis; Tony memakai pengali tempo di §4.

### 3.1 `idle` — loop, 2.0 s (60 f)
Napas dan berat badan, tidak pernah benar-benar diam.

| Frame | Pose |
|---|---|
| 0 | Netral: lengan turun santai (±70° dari T-pose), siku sedikit tekuk, Hips di tinggi rest −1 cm. |
| 30 | Tarik napas: Spine1/Spine2 tegak +3°, bahu naik 2°, kepala naik 2°, Hips +1 cm. |
| 60 | = frame 0. |

Lapisan kecil: kepala bergoyang kiri-kanan 3° dengan periode penuh (offset ¼ siklus) supaya tidak robotik.
**Tony:** 2.4 s, berat di kaki kanan (Hips miring 4°), tangan kiri di pinggang, kepala miring 6°.

### 3.2 `chop` — loop, 1.0 s (30 f), dua potongan per siklus
Memotong di talenan di depan perut.

| Frame | Pose |
|---|---|
| 0 | Badan condong ke depan 7°, kepala menunduk 10° melihat talenan (kepala chibi besar: tunduk lebih dari ini menutup wajah dengan topi). Tangan kiri di depan perut, telapak menahan bahan. Tangan kanan **naik** (siku 90°, tangan setinggi dada) = anticipation. |
| 5 | **Impact**: tangan kanan turun cepat ke tinggi talenan, bahu kanan turun, badan ikut turun 1 cm. |
| 7 | Hold impact (tangan sedikit memantul). |
| 15 | Naik lagi, tangan kiri bergeser 2 cm ke samping (menggeser bahan). |
| 20 | Impact kedua. |
| 22 | Hold. |
| 30 | = frame 0. |

**Tony:** 0.8 s (lebih cepat, pamer), tangan kanan naik lebih tinggi (setinggi kepala), kepala tidak menunduk sepenuhnya (melirik penonton).

### 3.3 `busy` — loop, 2.4 s (72 f)
Bolak-balik kiri-kanan, terlihat sibuk memasak di dua station.

| Frame | Pose |
|---|---|
| 0 | Tengah, netral kerja (badan condong 8°, kedua tangan di depan). |
| 12 | Putar badan ke **kiri** 35° (Hips 15°, Spine 20°), langkah kecil: berat ke kaki kiri. Tangan kanan menjangkau ke kiri (ambil bahan). |
| 18 | Hold, tangan kanan "mengambil". |
| 36 | Putar ke **kanan** 35°. Tangan kanan mengaduk/goyang wajan: lengan bawah berputar kecil. |
| 42–54 | Dua kali goyang wajan (lengan maju-mundur 10°), kepala mengikuti. |
| 72 | = frame 0. |

Kepala selalu sedikit **mendahului** arah putar (4 frame lebih awal) supaya terbaca "melihat dulu, baru bergerak".
**Tony:** 2.8 s, satu goyang wajan dengan gaya lempar. Putaran dasarnya 28° (setelah amplitudo ×1.3 ≈ 36°), karena 45° membuat wajahnya hampir menyamping.

### 3.4 `victory` — sekali main, 2.0 s (60 f), hold di akhir

| Frame | Pose |
|---|---|
| 0 | Netral. |
| 8 | Anticipation: lutut tekuk, Hips −6 cm, lengan ditarik ke belakang. |
| 16 | **Lompat**: Hips +12 cm, kedua lengan ke atas serong (V, ±60° di atas horizontal), kepala menengadah. |
| 24 | Mendarat, lutut tekuk (Hips −3 cm). |
| 32–52 | Fist pump: lengan kanan naik-turun 2× di atas kepala, lengan kiri mengepal di pinggang. |
| 60 | Pose akhir: kepalan kanan teracung serong ke atas di samping kepala (lurus ke atas tertutup kepala dan topi dari depan), dada membusung, kepala naik. Hold. |

**Tony:** tidak lompat tinggi (Hips +6 cm). Pose akhir sombong: tangan kiri di pinggang, tangan kanan menunjuk serong ke depan-samping (lurus ke depan tidak terbaca dari kamera depan), badan bersandar ke belakang 8°.

### 3.5 `lose` — sekali main, 2.4 s (72 f), hold di akhir

| Frame | Pose |
|---|---|
| 0 | Netral. |
| 6 | **Kaget**: badan terhentak ke belakang 10°, bahu naik, kedua tangan terangkat setengah. |
| 14 | Hold kaget. |
| 36 | Lemas: bahu jatuh, lengan menggantung, Spine membungkuk ke depan ±13°. |
| 52 | Lutut tekuk, Hips −8 cm, kepala menunduk 20°. |
| 72 | Pose akhir: tertunduk lesu, sedikit bergoyang lalu diam. Hold. |

**Tony:** lebih dramatis: di frame 36 kedua tangan memegang kepala, lalu jatuh berlutut (Hips turun sepanjang tulang kering), kepala menunduk ke depan.

## 4. Parameter gaya per karakter

| Parameter | Apis | Tony |
|---|---|---|
| Pengali tempo `idle` / `chop` / `busy` | 1.0 / 1.0 / 1.0 | 1.2 / 0.8 / 1.15 |
| Pengali amplitudo | 1.0 | 1.3 |
| Postur dasar (Spine) | condong +4° | membungkuk +8°, perut maju |
| Hips tinggi (dari rest) | 0.248 m | 0.213 m → semua offset Hips dikali 0.86 |
| Pose khusus | — | tangan di pinggang (`idle`, `victory`), tangan di kepala (`lose`) |

Catatan teknis: kedua rig punya nama bone sama, tapi orientasi rest berbeda sedikit. Pose ditulis sebagai rotasi
**relatif terhadap rest** di ruang lokal bone, lalu dicek ulang di Tony. Kalau ada bone yang menunjuk salah, koreksi
di tabel pose khusus Tony.

## 5. Pipeline Blender → Godot

1. Import `apis.glb` dan `tony.glb` ke Blender (satu file kerja `art/blender/chefs_anim.blend`), masing-masing di collection sendiri.
2. Cek rest pose dan sumbu bone (lengan, kepala, Spine, Hips) dengan pose tes.
3. Script pose membuat 5 **Action** per armature (`idle`, `chop`, `busy`, `victory`, `lose`), lalu push ke NLA.
4. Render cek: contact sheet beberapa frame per clip dari depan.
5. Export glTF Binary: +Y up, mesh + skin + material + tekstur tetap, animasi mode **Actions**, tanpa kamera/lampu.
   Timpa `godot/assets/characters/apis.glb` dan `tony.glb`.
6. Godot: atur loop `idle`/`chop`/`busy` lewat `.import` (`_subresources`), cek dengan test headless
   (AnimationPlayer berisi 5 clip, durasi dan loop benar) dan render beberapa frame.

## 6. Di luar scope (tahap berikutnya)

- Memasang GLB ke `scenes/stage/chef.tscn` dan memanggil clip dari `chef.gd` / Turn Director.
- Clip tambahan GDD §7.4: `hit`, `taunt`, `hop`.
- Props (pisau, talenan, wajan).
- Skala panggung: GLB tetap tinggi 1 m; skala di scene (Apis 2.3 m, Tony ×0.95 menurut CHARACTER_PLAN §6.1).

## 7. Hasil (dikerjakan)

- ✅ Script `art/blender/chef_anims.py` membuat kelima clip dari tabel pose di atas, satu karakter per sesi Blender:
  ```
  blender -b --factory-startup --python art/blender/chef_anims.py -- apis [--sheet <png>] [--no-export]
  blender -b --factory-startup --python art/blender/chef_anims.py -- tony
  ```
  Input: `art/blender/src/<nama>_src.glb` (GLB asli Tripo + Mixamo, tidak diubah). Output: `godot/assets/characters/<nama>.glb`
  dan file kerja `art/blender/<nama>_anim.blend` (Action per clip, disimpan di NLA). Blender yang dipakai: 5.1.
- ✅ Pose ditulis sebagai op di ruang rest (sumbu dunia, "ayun ke arah DOWN/FWD/OUT", flex siku, twist), lalu diubah ke
  rotasi lokal bone. Jongkok memakai IK dua tulang sederhana supaya kaki tetap menapak.
- ✅ Godot: loop `idle`/`chop`/`busy` diatur di `.import` (`_subresources`). `tests/glb_check.gd` (headless) memeriksa
  53 bone, mesh ber-skin, 5 clip, dan flag loop. `tests/glb_render.gd` (window) merender tiap clip di momen kuncinya.
- Penyesuaian dari rencana: tunduk kepala dan putaran `busy` Tony dikurangi, dan lengan pose `victory` dibuat serong
  (lihat catatan di tiap clip). Kepala chibi yang besar menutup gerakan yang terlalu lurus ke atas atau ke depan.
- Durasi di Godot +1 frame (mis. 2.03 s), karena frame terakhir loop = frame pertama. Tidak terlihat saat main.
