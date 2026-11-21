/**
 * Writes every icon of src/ui/icons.ts as a white SVG into godot/assets/icons/, so Godot
 * can tint it with `modulate` (same idea as CSS currentColor).
 * Run: node scripts/export-godot-icons.ts
 */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const root = join(import.meta.dirname, '..');
const src = readFileSync(join(root, 'src', 'ui', 'icons.ts'), 'utf8');
const out = join(root, 'godot', 'assets', 'icons');
mkdirSync(out, { recursive: true });

// icons.ts is browser code (touches document), so read its PATHS table as text.
const evenodd = new Set(
  [...(src.match(/EVENODD = new Set\(\[([^\]]*)\]/)?.[1] ?? '').matchAll(/'([^']+)'/g)].map((m) => m[1]),
);
let count = 0;
for (const m of src.matchAll(/^\s+(\w+): '([^']+)',$/gm)) {
  const [, name, d] = m;
  const rule = evenodd.has(name) ? ' fill-rule="evenodd"' : '';
  writeFileSync(
    join(out, `${name}.svg`),
    `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 24 24"><path fill="#ffffff"${rule} d="${d}"/></svg>\n`,
  );
  count++;
}
console.log(`Wrote ${count} icons → ${out}`);
