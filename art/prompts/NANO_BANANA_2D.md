# FINALE — Prompt Nano Banana untuk aset 2D

Prompt untuk membuat **frame kartu, ilustrasi kartu, modifier, dan icon pack** dengan Nano Banana
(Gemini image). Gaya mengikuti gambar referensi kartu pixel ("Archons Exile") dan `ART_DIRECTION.md`:
pixel art tebal, outline gelap, bingkai krem, badan gelap, blok biaya teal, palet "Market Street".

Penjelasan dalam bahasa Indonesia, **prompt dalam bahasa Inggris** (hasil Nano Banana lebih stabil).
Data yang dipakai: `godot/data/cards`, `godot/data/modifiers`, `godot/data/recipes`, `godot/assets/icons`,
`scripts/ui/pal.gd`.

---

## 0. Cara pakai (baca dulu)

1. **Satu kunci gaya dulu.** Buat frame kartu Ingredient (§2.1) sampai pas. Gambar itu jadi **gambar referensi**
   yang di-upload bersama setiap prompt berikutnya, plus gambar "Archons Exile". Tambahkan kalimat:
   `Match the exact pixel style, outline weight and palette of the attached reference image.`
2. **Tanpa teks di gambar.** Nama, biaya, angka, dan deskripsi digambar Godot (`card_view.tscn`). Nano Banana
   sering salah eja, jadi semua prompt meminta area teks **kosong**.
3. **Background datar.** Nano Banana tidak membuat PNG transparan. Semua prompt meminta latar **magenta
   `#FF00FF` rata**, lalu dihapus (magic wand / `rembg` / script). Magenta tidak dipakai di palet, jadi aman.
4. **Sheet, bukan satuan.** Ikon dan ilustrasi dibuat dalam grid (2×2, 3×3, 4×4). Satu sheet = gaya seragam.
   Potong per sel setelahnya.
5. **Downscale ke grid pixel asli.** Hasil Nano Banana ±1024 px dan "pixel"-nya tidak rata. Kecilkan dengan
   **Nearest Neighbor** ke ukuran art (tabel di bawah), lalu rapikan sedikit di Aseprite/LibreSprite
   (pixel nyasar, outline putus). Opsional: kuantisasi ke palet §1.2.
6. Simpan ke `godot/assets/pixel/<kategori>/<nama>.png`, import `Filter: Nearest`, `Mipmaps: off`.

| Aset | Aspect ratio prompt | Ukuran art akhir |
|---|---|---|
| Frame kartu / punggung | 3:4 | 48×64 (atau 96×128 kalau kartu di-scale ×2) |
| Ilustrasi kartu | 1:1 (sheet 2×2) | 32×32 per sel |
| Chip modifier | 1:1 | 24×24 |
| Emblem modifier | 1:1 (sheet 3×3 / 2×2) | 16×16 per sel |
| Ikon HUD / status / tag | 1:1 (sheet 4×4) | 12×12 atau 16×16 per sel |
| Ikon hidangan | 1:1 (sheet 4×4) | 24×24 per sel |

> Catatan jujur: ikon 12×12 hampir selalu butuh rapikan tangan setelah downscale. Kalau terlalu repot, pakai
> 16×16 dan biarkan Godot men-scale.

---

## 1. Blok gaya (tempel di awal setiap prompt)

### 1.1 STYLE
```
Chunky retro pixel art game asset, low resolution look (like a 48x64 sprite scaled up with nearest neighbor),
crisp hard square pixels, no anti-aliasing, no gradients, no blur, no dithering noise, flat shading with
1 highlight and 1 shadow tone per color, 1-pixel dark brown-black outline (#1e1410) around every shape,
limited warm palette. Front-facing, centered, orthographic, no perspective. Clean game UI asset for a
cooking-show deckbuilder. Plain flat solid magenta background (#FF00FF), nothing else in the background.
No text, no letters, no numbers, no watermark, no signature.
```

### 1.2 PALETTE (tambahkan kalau warna melenceng)
```
Use only this palette: wood #2a1a10 #3b2414 #5a3722 #7a4e30 #9c6a42; paper #fbf3e2 #f3e3c4 #d9c39a;
card rim #d9cdb8; card body #241d19; teal #2f6f7a #3f7fae #8fb3d1; hot #d8342c #a8231d #e07b28 #f2b632;
green #4d9a4a #5ea44f #2e5e2c; purple #8a3fb0 #7c63b5; ink #1e1410 #6b4a32; white #ffffff.
```

### 1.3 Warna tag bahan (dari `pal.gd`)

| Tag | Warna | Dipakai untuk |
|---|---|---|
| PROTEIN | `#e9a23b` | latar art, pip, ikon |
| CARB | `#c98c4a` | |
| VEGGIE | `#5ea44f` | |
| FAT | `#e6c84a` | |
| DAIRY | `#8fb3d1` | |
| SPICE | `#d8342c` | |
| SAUCE | `#9a4a2a` | |
| Technique | `#7c63b5` (art window `#2f6f7a`) | |
| Signature | rim emas `#f2d27a`, art `#4a2a3a` | |

---

## 2. Frame kartu

Layout mengikuti Card v2 di `card_view.gd` dan referensi: rim krem tebal, badan gelap, **blok biaya teal kiri
atas**, **pita nama** di atas, **jendela art** di tengah, kolom pip di sisi, **bar Quality** di bawah.
Semua slot kosong; Godot yang mengisi.

### 2.1 Frame Ingredient (kunci gaya, buat ini dulu)
```
[STYLE]
A single empty trading card frame, portrait 3:4, filling most of the image.
Thick light cream rim (#d9cdb8) with slightly chipped pixel corners and a 1px dark outline, small notch
in the middle of the bottom edge. Inside the rim a dark charcoal-brown card body (#241d19).
Top-left: a small square cost block in teal (#2f6f7a) with a lighter inner bevel, EMPTY (no number).
Top: a wide flat name banner in pale cream (#e9dcc6) next to the cost block, EMPTY (no text).
Middle: a large rectangular art window with a dark bevelled inner border, filled with plain flat
mid-grey (#6b6b6b) as a placeholder.
Left edge beside the art window: a small dark tab holding 2 empty round pip sockets.
Bottom: one long empty horizontal bar slot, dark with a thin cream border, divided into 3 segments.
Small empty dark text box under the art window.
Symmetrical, clean, readable at tiny size.
```

### 2.2 Frame Technique
```
[STYLE]
Same card frame layout as the attached reference card (cost block top-left, name banner, art window,
side pip tab), but a TECHNIQUE card: the art window is filled with flat teal (#2f6f7a), the side tab
and banner trim use muted purple (#7c63b5) accents, and there is NO bottom bar slot; instead the
empty text box is taller. Cream rim (#d9cdb8), dark body (#241d19). All slots empty, no text.
```

### 2.3 Frame Signature (rare)
```
[STYLE]
Same card frame layout as the attached reference card, but a legendary SIGNATURE DISH card:
the rim is warm gold (#f2d27a with #f2b632 highlights), a small pixel crown ornament sits on top of the
rim center, tiny sparkle pixels (#ffffff) on two corners, the name banner is gold (#f2b632),
the art window is filled with deep plum (#4a2a3a). Cost block stays teal. All slots empty, no text.
```

### 2.4 Punggung kartu
```
[STYLE]
The back side of a playing card, portrait 3:4, same cream rim (#d9cdb8) and dark body (#241d19)
as the attached reference card. Center emblem: a crossed chef knife and wooden spoon over a round
copper frying pan, in cream and orange (#e07b28), framed by a simple diamond border.
Small repeating checker pattern of two dark browns (#241d19, #3b2414) behind the emblem.
Symmetrical. No text.
```

### 2.5 Varian tag (opsional, edit gambar)
Upload frame §2.1 lalu:
```
Edit this card frame: recolor only the side pip tab and the thin trim around the art window to {TAG COLOR},
and fill the art window with a darker shade of {TAG COLOR}. Keep everything else pixel-identical.
```
Ganti `{TAG COLOR}` dengan warna di §1.3 (mis. `VEGGIE green #5ea44f`).

---

## 3. Ilustrasi kartu (isi jendela art, 32×32)

Gaya seperti pedang di referensi: satu objek besar di tengah, sedikit miring, outline gelap, latar jendela
diberi pola titik/partikel samar. **Latar tetap magenta** supaya bisa dipotong; warna jendela sudah dari frame.

Template sheet 2×2:
```
[STYLE]
A 2x2 sprite sheet of 4 separate food illustrations for card art, each centered in its own equal square
cell, generous empty margin, cells separated by plain magenta (#FF00FF). Each object is big, bold,
slightly tilted (about 15 degrees), with a 1px dark outline, 3-4 tones per color and one small white
shine pixel. Same scale and lighting (light from top-left) in every cell.
Top-left: {A}. Top-right: {B}. Bottom-left: {C}. Bottom-right: {D}.
```

| Sheet | {A} | {B} | {C} | {D} |
|---|---|---|---|---|
| **Protein** | raw marbled beef steak, red with white fat streaks | raw chicken drumstick, pale pink with bone end | white fish with blue-grey scales and tail | a single brown egg, slightly cracked |
| **Carb** | a loaf of crusty bread, golden brown | a bundle of dry spaghetti tied with a string | a small bowl of white rice | a pot of steaming water with pasta (spare) |
| **Veggie / Fat** | ripe red tomato with green leaves | a cut purple onion showing rings | a brown button mushroom | a stick of yellow butter on a small dish |
| **Dairy / Spice / Sauce** | a wedge of yellow cheese with holes | a red chili pepper with green stem | a garlic bulb with one clove apart | a glass jar of red tomato sauce |
| **Sauce 2 + cadangan** | a small pot of golden broth stock with steam | an empty cutting board (spare) | a whisk (spare) | a salt shaker (spare) |

Teknik (latar jendela teal, jadi objek pakai warna terang):
```
[STYLE]
A 2x2 sprite sheet of 4 cooking-show TECHNIQUE illustrations for card art, each centered in its own equal
square cell, cells separated by plain magenta (#FF00FF). Bold, dynamic, readable at 32x32.
Top-left: QUICK CHOP — a cleaver mid-swing chopping a carrot, motion lines, flying pieces.
Top-right: FLAMBE — a frying pan with a tall orange-yellow flame burst (#e07b28, #f2b632).
Bottom-left: DEEP BREATH — a calm chef hat with soft blue (#8fb3d1) breath swirls around it.
Bottom-right: STARE DOWN — two narrowed glaring eyes under a frowning brow, small sweat drop.
```
```
[STYLE]
A 2x2 sprite sheet of 4 cooking-show TECHNIQUE illustrations, same rules as before.
Top-left: MISE EN PLACE — three small prep bowls with chopped ingredients lined up neatly.
Top-right: CROWD PLEASER — a microphone with hearts and stars popping out.
Bottom-left: SIGNATURE DISH — a golden serving cloche lifted with light rays and sparkles.
Bottom-right: spare — a chef's knife crossed with a wooden spoon.
```

Nama file: `godot/assets/pixel/card_art/<card_id>.png` (`beef`, `chicken`, `fish`, `egg`, `bread`, `pasta`,
`rice`, `tomato`, `onion`, `mushroom`, `butter`, `cheese`, `chili`, `garlic`, `tomatoSauce`, `stock`,
`quickChop`, `flambe`, `deepBreath`, `stareDown`, `miseEnPlace`, `crowdPleaser`, `signature`).

---

## 4. Modifier (Chef's Flow)

10 modifier dari `MODIFIERS.md`. Tiap modifier = **chip** (bingkai per rarity) + **emblem** (ikon unik).
Saat ini HUD memakai ikon generik (`heat`, `check`, ...); emblem ini menggantikannya.

### 4.1 Chip / bingkai (2 rarity)
```
[STYLE]
Two small square badge frames side by side, each in its own cell, separated by magenta (#FF00FF),
for power-up modifiers in a card game. Each badge: rounded-square pixel frame, dark body (#241d19)
with an EMPTY center for an icon, a small empty circle socket on the bottom-right corner for a stack number.
Left badge COMMON: cream rim (#d9cdb8) with a teal (#2f6f7a) inner line.
Right badge RARE: gold rim (#f2b632) with a purple (#8a3fb0) inner line and two tiny white sparkle pixels.
No text, no icon inside.
```

### 4.2 Pick card modifier (overlay FlowPick, opsional)
```
[STYLE]
A tall reward card frame, portrait 3:4, for choosing a power-up. Cream paper body (#fbf3e2) like an
order ticket, torn zig-zag top edge, a round empty emblem socket in the upper third, a small ribbon
banner below it (EMPTY), and an empty text area at the bottom. A thin colored stripe on the left edge
in teal (#2f6f7a). No text.
```
Varian Rare: `...stripe in gold (#f2b632) and a small purple (#8a3fb0) gem at the top.`

### 4.3 Emblem modifier (sheet 3×3, sel ke-9 cadangan)
```
[STYLE]
A 3x3 sprite sheet of 9 bold power-up emblems for a cooking card game, each centered in its own equal
square cell, cells separated by plain magenta (#FF00FF). Each emblem is a single simple silhouette that
reads at 16x16 pixels, thick 1px dark outline, 2-3 tones, one white shine pixel. Same scale in every cell.
Row 1:
 1 HOT PAN — a black frying pan glowing red-hot with small flames on the rim.
 2 STEADY HANDS — two open chef hands with a soft blue (#8fb3d1) shield glow.
 3 ENCORE — a gold star with a small "plus" spark, like a bonus star.
Row 2:
 4 EXTRA BURNER — a stove burner ring with an extra blue-orange flame.
 5 PREP COOK — a small stack of three cards with a chef hat on top.
 6 CROWD FAVORITE — a raised hand-clap with tiny hearts.
Row 3:
 7 SPICE WHISPERER — a red chili pepper with a small speech-swirl breath.
 8 FREE MOVE — a curved double arrow looping between two small card shapes.
 9 spare — a wooden spoon.
```
```
[STYLE]
A 2x2 sprite sheet of RARE power-up emblems, same rules, each with a faint gold (#f2b632) aura of pixels.
Top-left: MISE MASTER — three tidy prep bowls with a small gold crown above.
Top-right: PLATING PRO — tweezers placing a leaf garnish on a plate, with two sparkles.
Bottom-left: spare — a gold chef hat.
Bottom-right: spare — a purple gem.
```

Nama file: `godot/assets/pixel/modifiers/<id>.png` (`hot_pan`, `steady_hands`, `encore`, `extra_burner`,
`prep_cook`, `crowd_favorite`, `spice_whisperer`, `free_move`, `mise_master`, `plating_pro`).

---

## 5. Icon pack

Menggantikan SVG di `godot/assets/icons` (nama file tetap sama supaya kode tidak berubah). Ikon kecil,
dibaca di 12–16 px, jadi semua prompt meminta **siluet tebal** tanpa detail halus.

Aturan umum, tempel setelah STYLE:
```
Tiny game UI icons. Each icon is one bold, instantly readable silhouette that must still read at
12x12 pixels: no thin lines, no small details, max 3 colors plus outline, thick 1px dark outline.
Each icon centered in its own equal square cell, cells separated by plain magenta (#FF00FF).
All icons same visual weight and size.
```

### 5.1 Tag bahan (sheet 3×3)
```
[STYLE] [ICON RULES]
A 3x3 icon sheet of ingredient category icons:
Row 1: PROTEIN — a meat drumstick (#e9a23b). CARB — a slice of bread (#c98c4a). VEGGIE — a green leaf (#5ea44f).
Row 2: FAT — a butter stick / oil drop (#e6c84a). DAIRY — a milk bottle (#8fb3d1). SPICE — a red chili (#d8342c).
Row 3: SAUCE — a sauce bottle / ladle drip (#9a4a2a). TECHNIQUE — a chef knife (#7c63b5). spare — a salt shaker.
```
File: `PROTEIN`, `CARB`, `VEGGIE`, `FAT`, `DAIRY`, `SPICE`, `SAUCE`, `technique`.

### 5.2 Stat & resource (sheet 3×3)
```
[STYLE] [ICON RULES]
A 3x3 icon sheet of battle stat icons:
Row 1: HEAT — an orange flame (#e07b28). HYPE — a lightning bolt in gold (#f2b632). COMPOSURE — a blue shield (#3f7fae).
Row 2: CONFIDENCE — a red heart with a chef hat notch (#d8342c). PRESSURE — a downward fist / impact burst (#a8231d). QUALITY — a gold star (#f2b632).
Row 3: SERVE — a silver serving cloche. DRAW — a card with an up arrow. DISCARD — a card with a down arrow into a bin.
```
File: `heat`, `hype`, `composure`, `confidence`, `pressure`, `quality`, `serve`, `draw`, `discard`.

### 5.3 Status (sheet 3×3)
Dari `status_defs.gd`: spicy, flustered, rattled, burnt (debuff); focus, inspired (buff).
```
[STYLE] [ICON RULES]
A 3x3 icon sheet of status effect icons. Debuffs have a thin red (#d8342c) corner mark, buffs a thin green (#4d9a4a) corner mark.
Row 1: SPICY — a red chili with heat waves. FLUSTERED — a spiral dizzy face swirl in pink-red. RATTLED — a shaking cracked plate.
Row 2: BURNT — a black burnt smoking pan with grey smoke. FOCUS — an eye inside a target ring (teal #2f6f7a). INSPIRED — a light bulb with sparkles (gold).
Row 3: BUFF — an up arrow (green). TAUNT — an angry speech bubble with an exclamation mark. spare — a sweat drop.
```
File: `spicy`, `flustered`, `rattled`, `burnt`, `focus`, `inspired`, `buff`, `taunt`.

### 5.4 UI umum (sheet 3×3)
```
[STYLE] [ICON RULES]
A 3x3 icon sheet of general UI icons:
Row 1: CHECK — a bold green check mark. CROWN — a small gold crown. ARROW — a thick right arrow.
Row 2: BOOK — a closed recipe book with a bookmark. TIPS — a question mark in a round bubble. SETTINGS — a gear.
Row 3: LOCK — a padlock. CLOSE — a bold X. PLAY — a right-pointing triangle.
```
File: `check`, `crown`, `arrow`, `book`, `tips`, `settings`, `lock`, `close`, `play`.

### 5.5 Metode masak (tiket, sheet 2×2)
```
[STYLE] [ICON RULES]
A 2x2 icon sheet of cooking method icons for an order ticket:
Top-left: FRY — a frying pan with oil drops. Top-right: GRILL — a grill grate with flame under it.
Bottom-left: BOIL — a pot with bubbles and steam. Bottom-right: RAW — a cutting board with a knife.
```
File: `method_fry`, `method_grill`, `method_boil`, `method_raw`.

### 5.6 Ikon hidangan (13 resep, sheet 4×4, 24×24)
```
[STYLE]
A 4x4 sprite sheet of 16 finished dish icons for a cooking game, each plated on a small round
white-cream plate (#fbf3e2) seen from a 3/4 top angle, centered in its own equal square cell,
cells separated by plain magenta (#FF00FF). Bold readable shapes, 1px dark outline, appetizing warm colors.
Row 1: toast with butter; folded omelette with green herbs; fresh green salad bowl; classic steak with garlic.
Row 2: two meat skewers; mixed grill platter; arrabbiata penne in red sauce; hot chicken wings in red glaze.
Row 3: warm soup bowl with steam; mac and cheese; mushroom risotto; tall burger with cheese and lettuce.
Row 4: sandwich cut diagonally; spare: empty plate; spare: covered cloche; spare: burnt black dish with smoke.
```
File: `godot/assets/pixel/dishes/<recipe_id>.png` (`toast`, `omelette`, `freshSalad`, `classicSteak`, `skewers`,
`mixedGrill`, `arrabbiata`, `hotWings`, `warmSoup`, `macAndCheese`, `mushroomRisotto`, `burger`, `sandwich`).
Sel "burnt dish" bisa dipakai untuk hasil Improvised.

---

## 6. Prompt perbaikan (kalau hasil meleset)

| Masalah | Tambahkan / kirim ulang |
|---|---|
| Terlalu halus, mirip lukisan | `Strictly pixel art. Every pixel is a visible hard square. No soft shading, no gradients, no painterly texture.` |
| Pixel tidak seragam ukurannya | `All pixels must be the same size on one uniform grid, as if drawn at 32x32 and scaled up 32x.` |
| Muncul teks / huruf | `Remove all text and letters. Leave the banner and boxes completely empty.` |
| Latar tidak rata / ada bayangan | `Background must be one flat solid #FF00FF with no shadow, no gradient, no floor.` |
| Gaya beda antar sheet | Upload sheet yang sudah bagus + `Match the exact style, outline and scale of the attached sheet.` |
| Warna di luar palet | Tempel blok PALETTE §1.2 |
| Ikon terlalu detail | `Simplify to a chunky silhouette readable at 12x12. Remove small details.` |

---

## 7. Checklist produksi

- [ ] Frame Ingredient (kunci gaya) disetujui
- [ ] Frame Technique, Signature, punggung kartu
- [ ] 5 sheet ilustrasi bahan + 2 sheet teknik
- [ ] Chip modifier Common/Rare + 2 sheet emblem modifier
- [ ] Icon pack: tag, stat, status, UI, metode, hidangan
- [ ] Semua di-downscale Nearest, latar magenta dihapus, disimpan di `godot/assets/pixel/...`
- [ ] Hook ke Godot: `card_view.tscn` (frame + `%ArtIcon`), chip modifier di `duel_ui.tscn`, `Ui.icon_tex()`
