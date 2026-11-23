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

### Easing (revisi 2)

Setiap key bisa memberi easing pada segmen yang **menuju** key itu. Ini yang membuat gerakan terasa tegas, bukan melayang:

| Easing | Blender | Dipakai untuk |
|---|---|---|
| `in` | Cubic, ease-in | Mempercepat ke arah impact: pisau menghantam, mendarat, jatuh berlutut |
| `out` | Back, ease-out (overshoot 1.2) | Tiba di pose lalu memantul sedikit: recoil pisau, sampai di station, pose kemenangan |
| `snap` | Expo, ease-out | Lepas sangat cepat lalu melambat: kaget, lompat, lempar wajan |

### 3.2 `chop` — loop, 1.2 s (36 f), ritme "chop, chop, CHOP"
Seluruh badan ikut memotong: condong dan turun di setiap hantaman.

| Frame | Pose | Easing |
|---|---|---|
| 0 | **Angkat**: pisau di tangan kanan setinggi kepala (lengan atas naik ke samping, siku 120°), bahu kanan naik, badan sedikit tegak. Tangan kiri menahan bahan di depan perut. | |
| 4 | **Hantam**: tangan kanan lurus ke talenan, badan condong 10°+8°, kepala mengangguk, Hips turun 3.5 cm. | `in` |
| 6 | Recoil kecil. | `out` |
| 10–16 | Ulangi, tangan kiri bergeser 6° ke samping (menggeser bahan). | |
| 24 | **Angkat besar**: tangan lebih tinggi, badan sedikit mundur. Tony melirik penonton (kepala 22°). | |
| 28 | **Hantam besar**: Hips turun 5.5 cm, badan condong 14°. | `in` |
| 31 | Recoil. | `out` |
| 36 | = frame 0. | |

**Tony:** tempo 0.85, amplitudo ×1.15, tangan diangkat lebih tinggi, kepala tidak menunduk.

### 3.3 `busy` — loop, 2.4 s (72 f)
Ambil bahan di kiri, masukkan ke panci di tengah, goyang dan lempar wajan di kanan. Melompat kecil antar station.

| Frame | Pose | Easing |
|---|---|---|
| 0 | Tengah, posisi kerja. | |
| 4 | Kepala melirik ke kiri lebih dulu. | |
| 9 | **Tiba di kiri**: badan berputar 50° total (Hips 35%, Spine 65%, kaki diputar balik supaya tetap menapak), Hips geser 3 cm. Tangan kanan menjangkau jauh menyilang badan, tangan kiri terbuka untuk keseimbangan. | `out` |
| 14 | **Ambil**: badan menunduk, jongkok 3 cm, tangan menggenggam. | `in` |
| 19 | Lompat kecil ke tengah (Hips +3 cm), bahan dibawa. | `snap` |
| 24 | **Masukkan ke panci**: kedua tangan ke depan-bawah, badan condong 16°, jongkok. | `in` |
| 27 | Memantul. | `out` |
| 30 | Kepala melirik ke kanan. | |
| 35 | **Tiba di kanan**, memegang gagang wajan. | `out` |
| 39–51 | Dua kali goyang wajan: dorong (`in`) dan tarik (`out`), badan ikut turun naik. | |
| 55 | **Lempar wajan**: lengan naik, badan mundur 12°, kepala menengadah mengikuti makanan, Hips +3.5 cm. | `snap` |
| 61 | **Tangkap**: jongkok 3.5 cm. | `in` |
| 66 | Kembali ke tengah dengan memantul. | `out` |
| 72 | = frame 0. | |

**Tony:** tempo 1.1, amplitudo ×1.1.

### 3.4 `victory` — sekali main, 2.0 s (60 f), hold di akhir

**Apis** (lompat gembira):

| Frame | Pose | Easing |
|---|---|---|
| 0 | Netral. | |
| 7 | **Ancang-ancang**: jongkok 9 cm, badan condong 22°, kedua lengan ditarik jauh ke belakang. | |
| 13 | **Lompat**: Hips +20 cm, kaki ditekuk di udara, kedua lengan V tinggi, kepala menengadah. | `snap` |
| 19 | Turun, kaki mulai lurus. | |
| 22 | **Mendarat**: squash, jongkok 7 cm, lengan terbuka. | `in` |
| 28–43 | Dua fist pump: kepalan kanan naik (`out`), turun dengan badan ikut jongkok (`in`). Kepalan kiri di pinggang. | |
| 50 | **Pose akhir**: kepalan kanan serong ke atas, dada membusung, kepala menengadah. Hold sampai 60. | `out` |

**Tony** (sombong): ancang-ancang kecil, lompat kecil 9 cm (`snap`), mendarat, lalu **tertawa terbahak**: badan bersandar ke belakang, tangan kiri di pinggang, tangan kanan di perut, badan berguncang 4× (frame 22–44). Frame 49: **menunjuk** lawan serong ke depan-samping dengan overshoot (`out`), hold.

### 3.5 `lose` — sekali main, 2.4 s (72 f), hold di akhir

Awal yang sama untuk keduanya: frame 5 **kaget** (`snap`): melompat mundur 3.5 cm dan naik 4 cm, kedua tangan ke wajah, bahu naik, kepala terhentak ke belakang. Frame 8–17: gemetar kiri-kanan.

**Apis** (kecewa):

| Frame | Pose | Easing |
|---|---|---|
| 30 | Kempis: bahu turun, lengan jatuh. | |
| 40 | **Ambruk**: jongkok 11 cm, badan condong, lengan menggantung ke depan. | `in` |
| 45 | Memantul sedikit. | `out` |
| 55 | Tarik napas: bahu naik, kepala sedikit naik. | |
| 66 | **Menghela napas**: bahu jatuh, kepala menunduk dan miring. Hold. Wajah tetap terlihat dari depan. | `in` |

**Tony** (drama): frame 22 memegang kepala (`out`), 27–37 menggeleng 3× tidak percaya, frame 43 **jatuh berlutut** (`in`, memantul di 47), frame 52–63 memukul lantai 2× dengan kedua kepalan (`in`/`out`), lalu tertunduk. Hold.

## 4. Parameter gaya per karakter

| Parameter | Apis | Tony |
|---|---|---|
| Pengali tempo `idle` / `chop` / `busy` | 1.0 / 1.0 / 1.0 | 1.2 / 0.85 / 1.1 |
| Pengali amplitudo (`idle` / `chop` / `busy`) | 1.0 | 1.3 / 1.15 / 1.1 (`victory`, `lose` punya pose Tony sendiri) |
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

- ~~Memasang GLB ke `scenes/stage/chef.tscn` dan memanggil clip dari `chef.gd`~~ ✅ (lihat §7).
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
- **Revisi 2** (feedback: terlalu kaku dan kecil): `chop`, `busy`, `victory`, `lose` dibuat ulang dengan pose lebih besar
  dan easing per key (§3, tabel Easing). `idle` tetap. `chop` jadi 3 potongan per siklus (1.2 s). Lompat `victory`
  20 cm dengan kaki ditekuk. `lose` Apis ambruk dengan wajah tetap terlihat, Tony memukul lantai.
- Cek sheet tanpa export: `-- apis --sheet <png> --no-export --clips chop,busy --cols 12 --view front --size 220`.
- ✅ **Terpasang di game.** `stage.tscn`: model jadi child `Player/apis` dan `Rival/tony` (skala 2.6 dan 2.47, naik 0.3 m
  supaya tangan yang bekerja terlihat di atas counter). `Chef.character` memilih model, dan Rosa (belum ada model) memakai
  placeholder. `main.gd` → `_bind_chefs`: `card_played` → `chop`, `dish_served` → `busy`, `duel_ended` → `victory`/`lose`.
  Bob dan hop prosedural hanya untuk placeholder, tapi flinch saat kena Pressure tetap. Test: `tests/chef_drive.gd`.
