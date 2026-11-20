/**
 * SVG icon sprite: one <symbol> per icon, injected once, used via <use href="#i-name">.
 * Single-color shapes on a 24×24 grid; color comes from CSS (currentColor), so the same
 * icon can sit on a cream panel or a dark bar. Replaces every emoji in the UI.
 */
const PATHS: Record<string, string> = {
  // ---- core stats
  heat: 'M12 2c.6 3.6 4.9 5.6 4.9 11.1A4.9 4.9 0 0 1 7.1 13c0-2.6 1.4-4 2-6.2 1.1 1 1.8 2.3 1.8 4C12.3 8.6 12.4 5.4 12 2z',
  composure: 'M12 2l8.5 3.2v6.1c0 5.2-3.6 9.2-8.5 10.7-4.9-1.5-8.5-5.5-8.5-10.7V5.2z',
  pressure: 'M20.5 2.5c.6 3.8-1.2 7.6-5.1 11.5l-3.6 3.6-2.4-2.4 3.6-3.6c3.9-3.9 3.7-7.2 7.5-9.1zM8.2 15.2l2.6 2.6-1.4 1.4 1.2 1.2-1.6 1.6-1.2-1.2-1.7 1.7-2.6-2.6 1.7-1.7-1.2-1.2 1.6-1.6 1.2 1.2z',
  confidence: 'M12 21s-8.5-5.2-8.5-11.4A4.7 4.7 0 0 1 12 6.8a4.7 4.7 0 0 1 8.5 2.8C20.5 15.8 12 21 12 21z',
  tips: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zm0 3.5a5.5 5.5 0 1 1 0 11 5.5 5.5 0 0 1 0-11z',
  hype: 'M12 2l2.9 6.2 6.8.8-5 4.7 1.3 6.8L12 17.1l-6 3.4 1.3-6.8-5-4.7 6.8-.8z',
  draw: 'M8 2.5h10a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V4.5a2 2 0 0 1 2-2zM3.5 6.5H5V18a2.5 2.5 0 0 0 2.5 2.5H16V22H5.5a2 2 0 0 1-2-2z',
  discard: 'M6 5h12l-1 16H7zM4 3h16v1.5H4zM9.5 1.5h5V3h-5z',
  serve: 'M2.5 17.5h19V20h-19zM12 4.5a1.6 1.6 0 0 1 1.6 1.6v.5A8.3 8.3 0 0 1 20.3 16H3.7a8.3 8.3 0 0 1 6.7-9.4v-.5A1.6 1.6 0 0 1 12 4.5z',
  book: 'M3 4.5c3-1 6-1 8.2.8V21c-2.2-1.8-5.2-1.8-8.2-.8zM21 4.5c-3-1-6-1-8.2.8V21c2.2-1.8 5.2-1.8 8.2-.8z',
  pixel: 'M3 3h8v8H3zm10 0h8v8h-8zM3 13h8v8H3zm10 0h8v8h-8z',
  arrow: 'M4 10.5h11l-4-4L13 4.5l7.5 7.5-7.5 7.5-2-2 4-4H4z',
  crown: 'M3 7.5l4.5 4L12 4l4.5 7.5 4.5-4-2 12.5H5z',
  check: 'M9 16.2l-4.2-4.2-1.8 1.8 6 6 12-12-1.8-1.8z',
  // ---- intents
  taunt: 'M4 3h16a1 1 0 0 1 1 1v11a1 1 0 0 1-1 1H9.5L5 20v-4H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1zm6.8 2.5v5.5h2.4V5.5zm0 7v2.2h2.4v-2.2z',
  buff: 'M12 3l7.5 8.5H15V21H9v-9.5H4.5z',
  // ---- statuses
  spicy: 'M16.2 3.5c1.4-.9 3.1-.2 3.1 1.4-1.2-.4-2.1.3-2.3 1.3 2.7 1.6 3.6 4.6 2.5 7.6-1.9 5.2-8.4 8.2-15.5 7.6 4.6-2 7.8-5.2 8.8-9.4.6-2.6 1.4-4.6 3.4-5.4z',
  flustered: 'M12 2.5s7 7.8 7 12.6a7 7 0 0 1-14 0c0-4.8 7-12.6 7-12.6z',
  rattled: 'M13.5 2L4.5 13.5h6L9.5 22l9-11.5h-6z',
  burnt: 'M7 19a4.5 4.5 0 0 1-.4-9A5.5 5.5 0 0 1 17 8.5a4.5 4.5 0 0 1 .5 10.5zM9 3.5c1.5 1-.5 2.5 1 3.5-2-.2-2.6-2.5-1-3.5z',
  focus: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm0 3a7 7 0 1 1 0 14 7 7 0 0 1 0-14zm0 3a4 4 0 1 0 0 8 4 4 0 0 0 0-8z',
  inspired: 'M12 2a7 7 0 0 0-4 12.7V17h8v-2.3A7 7 0 0 0 12 2zM9 18.5h6V20a2 2 0 0 1-2 2h-2a2 2 0 0 1-2-2z',
  // ---- ingredient tags
  PROTEIN: 'M14.5 2.5a6.5 6.5 0 0 1 6.5 6.5c0 3.2-2.3 5.6-5.5 6.4l-2.6.7-3.1 3.1a2.2 2.2 0 1 1-3.3-1.6 2.2 2.2 0 1 1-1.6-3.3l3.1-3.1.7-2.6c.8-3.6 2.8-6.1 5.8-6.1z',
  CARB: 'M3.5 10.5C3.5 6.4 7.3 4 12 4s8.5 2.4 8.5 6.5c0 1.2-.8 2-1.8 2.2V19a1 1 0 0 1-1 1H6.3a1 1 0 0 1-1-1v-6.3c-1-.2-1.8-1-1.8-2.2z',
  VEGGIE: 'M20.5 3.5C10.5 3.5 4 8.5 4 16.5c0 1.5.4 2.8 1 4l1.8-1.6c.2-5 3.7-8.8 8.7-10.4-3.9 2.3-6.5 6-7.1 10.7 7.2-.1 12.1-5.9 12.1-15.7z',
  FAT: 'M2.5 11.5L11 7l10.5 4.5v5.5L13 21.5 2.5 17zM11 9.2L5.6 12 13 15.2 18.4 12.3z',
  DAIRY: 'M2.5 9.5L16 4l5.5 5.5V20h-19zM8 12.5a1.8 1.8 0 1 0 0 3.6 1.8 1.8 0 0 0 0-3.6zm7.5-1a2.3 2.3 0 1 0 0 4.6 2.3 2.3 0 0 0 0-4.6zM12 17a1.3 1.3 0 1 0 0 2.6 1.3 1.3 0 0 0 0-2.6z',
  SPICE: 'M9 2h6v2.5H9zM8 5.5h8l1 3V20a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2V8.5zM10 10v2h1.5v-2zm2.5 0v2H14v-2zM10 13.5v2h1.5v-2zm2.5 0v2H14v-2z',
  SAUCE: 'M10 2h4v3.5l2.2 3.2V21a1 1 0 0 1-1 1H8.8a1 1 0 0 1-1-1V8.7L10 5.5zm-.2 10v5.5h4.4V12z',
  technique: 'M3.5 20.5l9.2-9.2 1.8 1.8-9.2 9.2zM14 3l1.2 3.3L18.5 7.5l-3.3 1.2L14 12l-1.2-3.3L9.5 7.5l3.3-1.2zM19 11l.8 2.2 2.2.8-2.2.8L19 17l-.8-2.2-2.2-.8 2.2-.8z',
};

/** Shapes that need the even-odd rule to cut holes (rings, cheese holes). */
const EVENODD = new Set(['tips', 'focus', 'DAIRY', 'FAT', 'taunt', 'SPICE', 'SAUCE']);

export function injectIconSprite(): void {
  if (document.getElementById('icon-sprite')) return;
  const symbols = Object.entries(PATHS)
    .map(
      ([id, d]) =>
        `<symbol id="i-${id}" viewBox="0 0 24 24"><path d="${d}"${EVENODD.has(id) ? ' fill-rule="evenodd"' : ''}/></symbol>`,
    )
    .join('');
  const holder = document.createElement('div');
  holder.innerHTML = `<svg id="icon-sprite" xmlns="http://www.w3.org/2000/svg" style="display:none">${symbols}</svg>`;
  document.body.prepend(holder.firstElementChild!);
}

/** Inline icon markup. `cls` adds color/size classes (e.g. "c-heat"). */
export function icon(name: string, cls = ''): string {
  return `<svg class="icon ${cls}" aria-hidden="true"><use href="#i-${name}"/></svg>`;
}

export function hasIcon(name: string): boolean {
  return name in PATHS;
}
