# FINALE — Prompt Nano Banana untuk eksplorasi warna UI

Tujuan: mencoba beberapa **arah warna** untuk seluruh UI duel tanpa menyentuh layout. Cara kerjanya
**image-to-image**: upload screenshot duel (1600×900), minta Nano Banana *hanya mengganti warna*.
Hasilnya dipakai sebagai referensi visual, lalu hex-nya diambil (eyedropper) dan dimasukkan ke
`scripts/ui/pal.gd`. Penjelasan Indonesia, **prompt Inggris**.

Dokumen ini melengkapi `NANO_BANANA_2D.md` (itu untuk membuat aset, ini untuk memilih palet).

---

## 0. Diagnosis tone saat ini (dari screenshot)

| Elemen | Warna sekarang | Catatan |
|---|---|---|
| Background panggung | gradasi peach → oranye hangat | Terang, saturasi tinggi, bersaing dengan kartu |
| Panel HUD (Player, Stations, Tony) | coklat gelap ~`#2a1f1a`, border `#3b2414` | Kontras bagus, tapi menyatu dengan karpet coklat di bawah |
| Rim kartu | krem `#d9cdb8` | Aman |
| Blok biaya / art Technique | teal `#2f6f7a` | Satu-satunya aksen dingin yang kuat |
| HP bar, END TURN, counter discard | merah `#d8342c` | **Tiga elemen berbeda fungsi memakai merah yang sama**, CTA tidak menonjol dari HP |
| Counter draw pile | biru `#3f7fae` | Biru murni terasa "dingin asing" di dunia hangat |
| Highlight / tombol aktif | emas `#f2b632` | Baik, tapi jarang dipakai |

Pertanyaan yang ingin dijawab eksplorasi: (1) apakah background perlu lebih tenang supaya kartu dan panel
menonjol, (2) apakah CTA (END TURN) perlu warna sendiri yang berbeda dari HP/bahaya,
(3) apakah dunia hangat-oranye dipertahankan atau diganti suasana lain.

---

## 1. Cara pakai

1. Upload screenshot duel sebagai gambar pertama. Pakai **aspect ratio 16:9**.
2. Tempel **PROMPT DASAR (§2)**, lalu ganti blok `{DIRECTION}` dengan salah satu arah di §3.
3. Generate 3–4 kali per arah, pilih yang paling bersih. Teks di gambar kadang melenceng sedikit, itu normal
   untuk eksplorasi. Yang dinilai hanya **warna dan kontras**.
4. Kalau suka, upload hasilnya lagi dan lanjut dengan prompt revisi (§5).
5. Bandingkan semua hasil berdampingan di **ukuran kecil** (kira-kira 25%). UI yang bagus tetap terbaca di situ.
6. Arah terpilih: ambil hex dengan eyedropper untuk tiap peran di tabel §3, lalu update `pal.gd`.

---

## 2. PROMPT DASAR (recolor, layout dikunci)

```
Recolor the attached game screenshot. This is a pixel-art cooking-show deckbuilder UI.

KEEP EXACTLY THE SAME: the layout, every panel, card, button, bar, icon, character, text, font, pixel
grid, outlines and shapes. Do not move, resize, add or remove anything. Do not redraw, restyle,
smooth or anti-alias. Keep crisp hard square pixels.

CHANGE ONLY THE COLORS, following this color direction:
{DIRECTION}

Color roles to respect:
- Stage background (behind everything): the main atmosphere color.
- HUD panels and station panels: dark, clearly separated from both the background and the floor strip.
- Card rim: light paper tone. Card body: dark.
- END TURN button: the single strongest call-to-action color on screen, different from the HP bar.
- HP / health bars: their own color, different from END TURN.
- Draw pile counter (left) and discard pile counter (right): two distinct, harmonious colors.
- Technique cards and cost blocks: the cool accent color.
- Selected / hovered highlight: bright accent (gold or equivalent).
Keep all text perfectly readable with strong contrast against its background.
Output the full screenshot at the same 16:9 framing.
```

---

## 3. Arah warna (isi `{DIRECTION}`)

Tiap arah punya palet dengan **peran** yang sama, jadi mudah dipetakan ke `pal.gd`.

### A. Night Market (malam pasar, lampu lentera)
Background jadi malam biru-indigo, kehangatan datang dari aksen. Kartu dan panel paling menonjol.
```
NIGHT MARKET. A street food market at night. Stage background: deep indigo to dusk violet gradient
(#1d1b3a to #3a2a5c) with a few warm lantern-orange glow spots (#e07b28). HUD panels: very dark
blue-black (#14122a) with a muted plum border (#3a2a5c). Card rim: warm cream (#f3e3c4), card body
dark (#1b1830). END TURN: glowing lantern orange (#e8892a) with a cream label. HP bar: fresh mint
green (#4fd18b). Draw counter: teal (#2f8f9a). Discard counter: crimson (#c2383f). Technique and cost
blocks: cyan-teal (#3fb6c4). Highlight: lantern gold (#f2b632).
```

### B. Retro Diner (teal, krem, merah ceri)
Dunia dingin-segar dengan merah ceri sebagai satu-satunya aksen panas.
```
RETRO DINER. 1950s diner palette. Stage background: soft aqua mint (#9fd8cf) to pale cream (#f3ead2).
HUD panels: deep teal-charcoal (#16363a) with a darker teal border (#0f2528). Card rim: cream
(#fbf3e2), card body: dark teal-black (#12262a). END TURN: cherry red (#d8342c) with cream label.
HP bar: butter yellow (#f2c94c) over a dark track. Draw counter: sky blue (#3f7fae). Discard
counter: tomato orange (#e0592b). Technique and cost blocks: teal (#2f8f8a). Highlight: bright butter
yellow (#f6d44a).
```

### C. Matcha Izakaya (hijau matcha, vermilion)
Tenang, natural, vermilion kecil sebagai penekanan.
```
MATCHA IZAKAYA. Japanese street-food stall palette. Stage background: soft matcha green (#b9c98a)
to warm rice-paper cream (#efe6c8). HUD panels: dark forest charcoal (#1f2a1f) with a mossy border
(#34462f). Card rim: rice-paper cream (#f1e8cf), card body: dark ink (#1a1f1a). END TURN: vermilion
red-orange (#d9482b) with cream label. HP bar: bright leaf green (#6fbf4a). Draw counter: indigo blue
(#3b5b8c). Discard counter: dusty plum (#8a4a6a). Technique and cost blocks: jade teal (#2f7f73).
Highlight: warm gold (#e8b83a).
```

### D. Bistro Burgundy (anggur, emas, krem) — acara masak mewah
Terasa premium, panggung TV mahal.
```
BISTRO BURGUNDY. Upscale TV cooking show. Stage background: warm wine burgundy (#6e2a35) fading to
rose-tan (#c98c7a), soft spotlight in the center. HUD panels: very dark aubergine (#231418) with a
brass border (#8a6a3a). Card rim: ivory (#f6ecd6), card body: dark espresso (#1e1412). END TURN:
rich gold (#e8b83a) with a dark burgundy label. HP bar: emerald green (#3fa66a). Draw counter: slate
teal (#3f7a8a). Discard counter: deep crimson (#a8231d). Technique and cost blocks: peacock teal
(#2f7a86). Highlight: bright champagne gold (#f6d77a).
```

### E. Slate & Neon Orange (kontras maksimal, UI-first)
Dunia netral gelap, hanya aksen yang berwarna. Paling terbaca.
```
SLATE AND NEON ORANGE. High-readability palette. Stage background: calm desaturated slate blue-grey
(#3b4252 to #5a6478), low saturation so cards pop. HUD panels: near-black charcoal (#161a22) with a
grey-blue border (#2a3140). Card rim: warm white (#f5efe2), card body: dark graphite (#1c2029).
END TURN: vivid orange (#ff7a1a) with a dark label. HP bar: lime green (#7ed957). Draw counter: cool
blue (#4a90d9). Discard counter: magenta-red (#d9435a). Technique and cost blocks: teal (#2fb3a8).
Highlight: electric yellow (#ffd23a).
```

### F. Candy Studio (pastel cerah, acara TV anak)
Ramah, ceria, saturasi sedang tinggi.
```
CANDY STUDIO. Bright cheerful kids cooking show. Stage background: pastel peach-pink (#ffc9b5) to
butter yellow (#ffeaa0). HUD panels: warm dark cocoa (#3a2230) with a berry border (#6a3a52). Card
rim: milk white (#fff6e6), card body: dark cocoa (#2a1a24). END TURN: hot pink (#ff4f8b) with white
label. HP bar: mint green (#58d68d). Draw counter: bubblegum blue (#4aa8e8). Discard counter: grape
purple (#8a5ad6). Technique and cost blocks: turquoise (#2fbfb0). Highlight: sunshine yellow (#ffd23a).
```

### G. Sunset Synthwave (ungu, pink, oranye)
Berani dan beda dari tema pasar. Cocok kalau game mau terasa "pertunjukan".
```
SUNSET SYNTHWAVE. Stage background: dusk gradient from deep purple (#2a1a4a) through magenta pink
(#c2448a) to orange (#ff9a4a) near the horizon. HUD panels: dark violet-black (#1a1230) with a purple
border (#4a2a7a). Card rim: pale lilac-cream (#f3e6f0), card body: dark violet (#1e1430). END TURN:
hot magenta (#ff3d8b) with white label. HP bar: neon cyan-green (#3df0b0). Draw counter: electric
blue (#4a7cff). Discard counter: orange-red (#ff5a3a). Technique and cost blocks: cyan (#2fd0e0).
Highlight: bright yellow (#ffd23a).
```

### H. Kontrol: Market Street (palet sekarang, dirapikan)
Untuk perbandingan. Menyelesaikan masalah 3 elemen merah dan background terlalu terang.
```
MARKET STREET REFINED. Keep the warm world but calmer. Stage background: muted warm apricot (#e8b58a)
to sand (#f0d9b0), lower saturation than now. HUD panels: dark walnut (#2a1a10) with a lighter wood
border (#5a3722). Card rim: cream (#d9cdb8), card body: dark (#241d19). END TURN: golden amber
(#f2b632) with a dark brown label. HP bar: leaf green (#5ea44f). Draw counter: teal (#2f6f7a).
Discard counter: brick red (#a8231d). Technique and cost blocks: teal (#2f6f7a). Highlight: bright
gold (#ffd24a).
```

### Tabel peran (isi setelah memilih, lalu pindahkan ke `pal.gd`)

| Peran | Night Market | Retro Diner | Matcha | Burgundy | Slate Neon | Candy | Synthwave | Refined |
|---|---|---|---|---|---|---|---|---|
| Background atas | `#1d1b3a` | `#9fd8cf` | `#b9c98a` | `#6e2a35` | `#3b4252` | `#ffc9b5` | `#2a1a4a` | `#e8b58a` |
| Panel | `#14122a` | `#16363a` | `#1f2a1f` | `#231418` | `#161a22` | `#3a2230` | `#1a1230` | `#2a1a10` |
| Rim kartu | `#f3e3c4` | `#fbf3e2` | `#f1e8cf` | `#f6ecd6` | `#f5efe2` | `#fff6e6` | `#f3e6f0` | `#d9cdb8` |
| CTA END TURN | `#e8892a` | `#d8342c` | `#d9482b` | `#e8b83a` | `#ff7a1a` | `#ff4f8b` | `#ff3d8b` | `#f2b632` |
| HP | `#4fd18b` | `#f2c94c` | `#6fbf4a` | `#3fa66a` | `#7ed957` | `#58d68d` | `#3df0b0` | `#5ea44f` |
| Cool accent | `#3fb6c4` | `#2f8f8a` | `#2f7f73` | `#2f7a86` | `#2fb3a8` | `#2fbfb0` | `#2fd0e0` | `#2f6f7a` |
| Highlight | `#f2b632` | `#f6d44a` | `#e8b83a` | `#f6d77a` | `#ffd23a` | `#ffd23a` | `#ffd23a` | `#ffd24a` |

---

## 4. Prompt tambahan

### 4.1 Moodboard bebas (kalau mau melihat arah di luar daftar)
```
Create a 3x2 grid of six color-palette mood panels for the UI of a pixel-art cooking-competition
deckbuilder. Each panel shows: one large background swatch, one dark UI-panel swatch, one cream card
swatch, one bright call-to-action button swatch, one health-bar swatch, and one cool accent swatch,
arranged as simple flat rectangles. Six different moods: night market, retro diner, matcha, burgundy
bistro, candy pastel, neon synthwave. No text, no labels, no gradients inside swatches.
```

### 4.2 Palet saja dari hasil yang disukai
Upload hasil recolor yang dipilih:
```
From the attached screenshot, extract the 10 most important UI colors and show them as a single
horizontal row of 10 flat square swatches on a plain white background, ordered: background top,
background bottom, HUD panel, panel border, card rim, card body, call-to-action button, health bar,
cool accent, highlight. No text.
```
Lalu eyedropper tiap swatch (atau minta Claude membaca hex dari gambar itu).

### 4.3 Komponen terisolasi (cek apakah palet tahan di elemen kecil)
Upload hasil recolor yang dipilih:
```
Using the exact color palette of the attached screenshot, show an isolated UI kit on a flat
neutral-grey background: one player HUD panel with an empty health bar, one card in Ingredient style
and one card in Technique style, one END TURN button, one draw-pile counter and one discard-pile
counter, one gold highlight frame. Same pixel-art style, hard square pixels, no text.
```

---

## 5. Prompt revisi (kalau hasil meleset)

| Masalah | Kirim ulang |
|---|---|
| Layout/teks berubah | `You changed the layout. Redo it and keep every element, position and shape pixel-identical to the first image. Change colors only.` |
| Jadi halus / seperti lukisan | `Strictly pixel art. Hard square pixels, no gradients, no soft shading, no blur. Same pixel grid as the original.` |
| END TURN kurang menonjol | `Make END TURN the single most saturated, brightest element on screen. No other button or bar may use its hue.` |
| HP dan END TURN masih mirip | `The HP bar and the END TURN button must be clearly different hues. Change the HP bar only.` |
| Background bersaing dengan kartu | `Lower the saturation and brightness of the stage background by 30 percent so the cards and panels stand out. Do not touch anything else.` |
| Panel menyatu dengan lantai bawah | `Make the HUD panels slightly darker than the bottom floor strip so their edges are clearly visible.` |
| Teks sulit dibaca | `Increase contrast of all text against its background. Keep text pixel-identical, change only the colors behind it.` |
| Terlalu banyak warna | `Reduce the palette to at most 12 colors total. Merge similar hues.` |
| Mau kombinasi dua arah | `Take the background and panels from image 1 and the button, bar and counter colors from image 2.` |

---

## 6. Checklist

- [ ] Generate 3 variasi tiap arah A–H (D–G opsional kalau waktu mepet)
- [ ] Susun berdampingan, lihat di ukuran 25%
- [ ] Pilih 1–2 arah, lakukan revisi §5
- [ ] Ekstrak palet (§4.2) dan cek kontras teks vs panel
- [ ] Update `scripts/ui/pal.gd` + background panggung di `main.tscn`, tes dengan `tests/ui_drive.gd`
