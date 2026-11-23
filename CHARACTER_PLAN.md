# FINALE — Character Plan (Blender → GLB → Godot)

> Dokumen pendamping [ART_DIRECTION.md](ART_DIRECTION.md) §2.3 dan §8. Dibuat 23 Nov 2026.
> Tiga gambar referensi (penyihir bertopi lebar, makhluk putih bermata besar, sprite berdaun) **hanya acuan rasa**.
> Tidak ada karakter, bentuk khas, atau warna yang disalin. Semua karakter di bawah adalah desain original Finale.

## 0. Keputusan (23 Nov)

| # | Pertanyaan | Keputusan |
|---|---|---|
| 1 | Spesies | **Manusia chibi bertopeng**: tetap manusia (rambut, baju, tangan, kaki), wajah disederhanakan jadi "topeng" krem |
| 2 | Proporsi | **1:2** (kepala = setengah tinggi badan). Menggantikan 1:3 di ART_DIRECTION §2.3 |
| 3 | Penonton | **4 base mesh** + ganti warna di Godot |
| 4 | Roster | **Apis + 5 rival**: Tony, Rosa, Marco, Élodie, Bruno |

---

## 1. Style bible: gabungan 3 referensi

| Dari referensi | Yang diambil | Yang **tidak** diambil |
|---|---|---|
| Penyihir bertopi (ref 1) | Low-poly **faceted**, flat shading tanpa tekstur, palet kalem hangat, **siluet ditentukan topi/jubah**, kaki tipis kecil | Topi penyihir lebar + jubah gelap + mata tunggal (desain mereka) |
| Makhluk putih (ref 2) | **Kepala besar bulat**, **mata hitam oval besar**, blush merah muda kecil, tangan-kaki pendek lucu, sedikit "aneh tapi imut" | Tubuh putih polos, tekstur kuas |
| Sprite berdaun (ref 3) | **Wajah topeng krem** terpisah dari kepala, mata gelap oval, badan bulat seperti kacang, **tangan mitten** tanpa jari, kaki pendek gemuk, warna matte pastel, toon shading halus | Topi daun + tangkai, hidung paruh, sayap/ekor |

**Rumus karakter Finale**
- **Kepala (50%)**: bola agak lonjong. Di depan ada **topeng wajah** krem (`#f3e3c4`) yang menempel seperti piring dangkal, sedikit menonjol dari kepala. Topeng: **2 mata hitam oval besar** berjarak lebar dan agak rendah, **blush** kecil merah muda di bawah mata, **tanpa mulut, tanpa hidung**. Ekspresi datang dari emote bubble (ART_DIRECTION §5), jadi wajah 3D tetap netral.
- **Rambut / topi**: blok besar low-poly di atas topeng. Ini **pembeda utama** tiap karakter, harus terbaca dari kamera tinggi.
- **Badan (35%)**: torso bulat seperti kacang, baju dan celemek jadi zona warna besar.
- **Kaki (15%)**: pendek, sepatu/boot sederhana.
- **Tangan**: mitten bulat tanpa jari. Lengan pendek.
- **Shading**: faceted flat, 1 cahaya hangat dari kiri atas, tanpa outline di gambar (outline nanti dari shader Godot).
- **Warna**: maksimal 5 zona warna per karakter, dari palet "Market Street" (ART_DIRECTION §3.1).

---

## 2. Cara pakai prompt di Nano Banana

1. Tiap prompt = **STYLE BLOCK** + **CHARACTER BLOCK** + **OUTPUT BLOCK**. Salin ketiganya berurutan.
2. Buat **Apis dulu**. Kalau hasilnya sudah pas, pakai gambar Apis sebagai **gambar referensi** untuk semua karakter berikutnya, dengan kalimat tambahan:
   `Use the attached image only as the style and proportion reference. Same rendering, same head-to-body ratio, same mask face. Create a different character:`
3. Jangan lampirkan 3 gambar referensi asli ke Nano Banana. Gaya sudah dideskripsikan di STYLE BLOCK, jadi hasilnya tetap original.
4. Kalau hasil pose kurang pas, ulangi dengan kalimat: `Redo in a strict front orthographic view, symmetrical A-pose, arms away from the body.`
5. Simpan hasil di `art/concepts/characters/<nama>_front.png` (folder di luar `godot/` supaya tidak ikut ter-import).

### STYLE BLOCK (sama untuk semua)
```
Stylized low-poly 3D character, chibi proportions with a 1:2 head-to-body ratio (the head is as tall as the rest of the body).
Faceted flat-shaded polygons, matte colors, no textures, soft toon lighting from the upper left, gentle ambient occlusion.
Muted warm cozy palette, maximum five color areas on the character.
The face is a smooth cream-colored mask-like plate on the front of the head: two large glossy black oval eyes set wide apart and slightly low, tiny soft pink blush marks under the eyes, no mouth, no nose, no eyebrows.
Round bean-shaped torso, short stubby arms with rounded mitten hands without fingers, short legs with simple small shoes.
Cute, slightly whimsical, readable silhouette, designed to be rebuilt as a game model in Blender.
```

### OUTPUT BLOCK (sama untuk semua)
```
Full body, strict front orthographic view, perfectly centered and symmetrical, neutral A-pose with arms angled 30 degrees away from the body and legs slightly apart, standing straight, looking at the camera.
Nothing held in the hands, no props touching the body.
Plain flat light grey background (#d0d0d0), no floor, no shadow on the background, no text, no logo, no watermark, no frame.
Square 1:1 image, the character fills about 85% of the image height.
Avoid: realistic human face, mouth, nose, fingers, outlines, cel-shading ink lines, pixel art, painterly brush texture, dynamic pose, perspective camera, side view, three-quarter view, multiple characters.
```

> Props (sendok, papan pizza, pisau daging, kantong krim) dibuat **terpisah** di Blender dan ditempel ke bone tangan. Itu sebabnya karakter dibuat bertangan kosong.

---

## 3. Karakter utama

### 3.1 Apis Tetrarch — MC
Koki muda dari dapur kecil keluarga, underdog. "Apis" = lebah, jadi ada sentuhan madu yang halus.
Siluet: **toque pendek yang lemas miring ke satu sisi** + ekor bandana yang berkibar.

```
CHARACTER: Apis, a young underdog cook from a small family kitchen.
A short soft chef toque that flops to the left side, with a mustard-yellow (#f2b632) band around it and two short bandana tails sticking out behind the head.
A few messy dark brown (#3b2414) hair tufts peeking out under the toque above the mask.
A teal (#2f6f7a) neckerchief tied at the front.
A cream (#fbf3e2) cook jacket with rounded collar, covered by an oversized hand-me-down apron in warm wood brown (#7a4e30) that reaches the knees, with one small square patch sewn on the apron and one small hexagon honey-shaped pocket.
Short dark brown pants, small mustard-yellow shoes.
Mood: earnest, hopeful, a little scrappy.
```

---

## 4. Rival (Market Street)

Skala di Blender relatif ke Apis (= 1.0). Ukuran berbeda membantu membaca "kelas" lawan.

| Rival | Skala | Siluet kunci | Warna utama |
|---|---|---|---|
| Tony | 0.95 | Ikat kepala + jambul rambut + handuk di bahu | Merah, putih, slate |
| Rosa | 1.0 | Mahkota kertas kecil di atas bandana + 2 kepang panjang | Merah panas, oranye, hijau |
| Marco | 1.1 | Rambut pompadour tinggi + kumis melengkung + rompi | Teal, krem, merah |
| Élodie | 1.05 | Toque tinggi ramping + pita besar + jas pastry mengembang | Krem, pink pucat, biru muda, cokelat |
| Bruno | 1.45, badan lebar | Topeng pelindung besi + celemek kulit tebal + bahu besar | Besi gelap, kayu tua, bara oranye |

### 4.1 Tony — street noodle cook (Duel, tutorial)
```
CHARACTER: Tony, a laid-back street noodle cook, the easy first opponent.
A red (#d8342c) cloth headband tied around the forehead above the mask with the knot and two short tails on the right side.
A tall spiky bundle of black hair sticking up out of the headband like a broom.
A white sleeveless undershirt, a small white towel draped over the left shoulder.
Loose slate-blue (#3f7fae) knee-length shorts tied with a rope belt, simple wooden sandals.
Slightly round belly.
Mood: relaxed, cheeky, overconfident.
```

### 4.2 Rosa — taco truck queen (Duel, trickster)
```
CHARACTER: Rosa, a quick-witted food truck queen who loves teasing her opponents.
A small gold-yellow (#f2b632) paper crown with three points pinned on top of a hot red (#d8342c) bandana.
Two long thick dark brown braids hanging over the front of the shoulders, each ending in a small green (#4d9a4a) chili-pepper-shaped hair tie.
Large round gold hoop earrings.
A short cropped orange (#e07b28) work jacket with rolled sleeves over a cream top, a short dark red half-apron around the waist with two front pockets.
Dark brown pants, chunky red sneakers.
Mood: sly, playful, mischievous.
```

### 4.3 Marco — pizza showman (Duel, showman)
```
CHARACTER: Marco, a flamboyant pizza showman who loves an audience.
A very tall glossy black pompadour hairstyle swept up and forward like a wave above the mask.
A thin curled black moustache attached to the lower part of the mask, curling upward at both ends.
A teal (#2f6f7a) and cream vertical-striped showman vest with two big gold buttons, over a cream shirt with puffy short sleeves.
A large red (#d8342c) bow tie.
Slim dark brown trousers, shiny cream shoes.
Chest pushed out proudly.
Mood: theatrical, proud, show-off.
```

### 4.4 Élodie — rival pâtissière (Elite, patient)
```
CHARACTER: Élodie, an elegant and precise rival pastry chef.
A very tall slim cylindrical chef toque in cream (#fbf3e2) with a pale pink pleated band.
A neat short chin-length cocoa brown (#5a3722) bob haircut framing the mask, with a large pale blue (#8fb3d1) ribbon bow at the back of the head that is visible as two loops on both sides.
A long cream double-breasted pastry coat with two rows of small cocoa buttons, flaring out like a short cape below the waist down to the knees.
Pale pink gloves as mitten hands.
Small cocoa brown ankle boots.
Very straight upright posture.
Mood: calm, precise, quietly superior.
```

### 4.5 "Iron" Bruno — butcher-turned-grill master (Boss)
```
CHARACTER: "Iron" Bruno, a huge butcher turned grill master, the final boss.
Much wider and heavier than the other characters: broad round shoulders, barrel chest, thick arms, big mitten hands, short thick legs.
Over the upper part of the cream mask he wears a dark iron-grey (#3b3b44) visor shaped like a grill grate with three horizontal bars, so only the two black oval eyes show between the bars.
A short dark wood-brown (#2a1a10) buzz cut on top.
A thick dark leather apron (#5a3722) with big metal rivets, covering a rust-red (#a8231d) shirt with rolled sleeves.
Ember-orange (#e07b28) wrist wraps on both forearms.
Heavy dark boots.
Mood: intimidating, heavy, smoldering heat.
```

---

## 5. Penonton (4 base mesh)

Penonton dibuat lebih sederhana (low-poly lebih rendah, tanpa rig penuh) dan **diwarnai ulang di Godot**. Jadi tiap base punya 3 zona warna tetap:
- **Zona A** (baju utama), **Zona B** (aksen: topi/syal/rambut), **topeng** krem tetap.

Di prompt, zona A dan B diberi warna default. Di Godot warnanya diganti per instance.

Tambahan untuk OUTPUT BLOCK penonton:
```
Simpler design than a main character: fewer details, bigger shapes, suitable for a low-poly crowd extra.
```

### 5.1 Crowd A — "Round Fan"
```
CHARACTER: a round, short, cheerful crowd member.
Very round chubby body in a chunky knit sweater (zone A, mustard #f2b632) and a small beanie hat with a pom-pom (zone B, teal #2f6f7a).
Short dark pants, small shoes.
Mood: excited, wholesome.
```

### 5.2 Crowd B — "Tall Hoodie"
```
CHARACTER: a tall, thin crowd member, taller than average but still chibi.
A long hoodie (zone A, slate blue #3f7fae) with the hood up, the hood has two small rounded cat-ear bumps on top (zone B, cream #f3e3c4 inner color).
Thin legs, simple sneakers.
Mood: shy, curious.
```

### 5.3 Crowd C — "Kid"
```
CHARACTER: a small child crowd member, about 70% the height of an adult chibi.
A big floppy bucket hat that is wider than the head (zone B, olive green #5ea44f).
A simple short-sleeved shirt (zone A, tomato red #d8342c), short shorts, round little shoes.
Mood: excited, wide-eyed.
```

### 5.4 Crowd D — "Elder"
```
CHARACTER: an old crowd member.
A grey hair bun on top of the head, a long knitted shawl wrapped around the shoulders like a small cape (zone B, dusty peach #e0a07a).
A long simple dress or coat (zone A, plum brown #6b4a32) reaching the ankles, slightly hunched posture.
Mood: warm, dignified.
```

---

## 6. Pipeline Blender → Godot (rencana, belum dikerjakan)

### 6.1 Modeling
| Item | Target |
|---|---|
| Tinggi Apis | **2.3 m** di Blender (sama dengan placeholder `scenes/stage/chef.tscn` sekarang: badan 1.6 + kepala), jadi kamera dan stage tidak perlu diubah |
| Budget poly | Apis & rival: **800–1500 tri**. Bruno: ≤ 2000. Penonton: **300–600 tri** |
| Wajah | Topeng = mesh terpisah sedikit menonjol. Mata = mesh oval hitam (bukan tekstur) supaya tajam di 640×360 |
| Sisi & belakang | Gambar hanya tampak depan, jadi kedalaman dan bagian belakang ditentukan saat modeling. Kalau perlu, buat prompt tampak samping nanti dari gambar depan yang sudah final |
| Origin | Di antara kaki, Z = 0 di lantai, menghadap −Y di Blender (jadi +Z di Godot) |

### 6.2 Warna
- **Satu tekstur palet** 24 warna (ART_DIRECTION §3.1) ukuran 32×32, filter nearest. UV tiap zona di-snap ke satu kotak warna. Satu material untuk semua karakter, cocok untuk renderer Compatibility.
- Penonton: zona A dan B memakai **vertex color** penanda (merah = A, hijau = B). Shader Godot mengganti warnanya dengan `instance uniform` per penonton.

### 6.3 Rig & animasi
- Armature sederhana: `root, hips, spine, head, hat, arm.L/R, hand.L/R, leg.L/R`. Penonton: `root, body, head` saja.
- Animasi per chef (GDD §7.4): `idle`, `cook`, `hit`, `taunt`, `defeated`, `hop`. Penonton: `idle`, `cheer` (bisa prosedural).
- Props di-parent ke `hand.R` lewat `BoneAttachment3D` di Godot.

### 6.4 Export
- glTF Binary (`.glb`), **+Y Up**, Apply Transform, tanpa kamera/lampu, animasi sebagai NLA/Actions dengan nama di atas.
- File: `godot/assets/models/characters/<nama>.glb` (`apis`, `tony`, `rosa`, `marco`, `elodie`, `bruno`, `crowd_a`…`crowd_d`).
- Di Godot: `chef.tscn` mendapat child instance `.glb` menggantikan Body/Head/Hat placeholder. `chef.gd` memanggil `AnimationPlayer` untuk flinch/hop yang sekarang masih prosedural. Kerumunan di `stage.gd` (`_spawn_crowd`) diganti dengan node penonton di scene, sesuai aturan "nodes in scenes".

### 6.5 Urutan kerja
1. Generate front view Apis → approve.
2. Generate 5 rival + 4 penonton dengan Apis sebagai referensi gaya → approve.
3. Blender: model Apis + tekstur palet + rig + 1 animasi `idle` → export → tes di Godot dengan shader outline dan pixel filter. **Ini gerbang**: kalau terbaca bagus di 640×360, lanjut.
4. Model 5 rival (mulai Tony & Rosa yang sudah ada di data), lalu penonton.
5. Animasi lengkap, props.
6. BG/panggung (rencana terpisah setelah karakter).
