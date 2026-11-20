/**
 * Graybox HUD (GDD §7.2): Confidence badge bottom-left, Tips next to it,
 * hand of cards at the bottom, Serve / End Turn buttons, rival intent label.
 * Static placeholder content for now; the duel logic will drive it later.
 */
export interface Hud {
  /** Move the rival intent label to a screen position (pixels). */
  setIntentPosition(x: number, y: number): void;
  onTogglePixel(handler: () => void): void;
  setPixelLabel(on: boolean): void;
}

const PLACEHOLDER_HAND = [
  { name: 'Egg', type: 'PROTEIN', cost: 0, text: 'Quality 1' },
  { name: 'Bread', type: 'CARB', cost: 0, text: 'Quality 1' },
  { name: 'Butter', type: 'FAT', cost: 0, text: 'Quality 1' },
  { name: 'Quick Chop', type: 'Technique', cost: 1, text: '6 Pressure' },
  { name: 'Deep Breath', type: 'Technique', cost: 1, text: '5 Composure' },
];

export function createHud(root: HTMLElement): Hud {
  root.innerHTML = `
    <div class="top-bar">
      <span class="title">FINALE</span>
      <span class="district">Market Street · Duel 1</span>
      <button class="btn small" id="toggle-pixel" title="Toggle pixel filter (P)">Pixel: OFF</button>
    </div>

    <div class="intent" id="intent">
      <div class="intent-name">Tony</div>
      <div class="intent-bubble">🔪 Prepping · 8</div>
      <div class="bar"><div class="bar-fill" style="width:100%"></div><span>Confidence 30/30</span></div>
    </div>

    <div class="badge-area">
      <div class="badge">
        <div class="badge-value">60<small>/60</small></div>
        <div class="badge-label">Confidence</div>
      </div>
      <div class="chip heat">🔥 3/3</div>
      <div class="chip tips">💰 0</div>
    </div>

    <div class="hand">
      ${PLACEHOLDER_HAND.map(
        (c) => `
        <div class="card ${c.type === 'Technique' ? 'technique' : 'ingredient'}">
          <div class="card-cost">${c.cost}</div>
          <div class="card-name">${c.name}</div>
          <div class="card-art"></div>
          <div class="card-type">${c.type}</div>
          <div class="card-text">${c.text}</div>
        </div>`,
      ).join('')}
    </div>

    <div class="actions">
      <button class="btn serve">SERVE <small>1🔥</small></button>
      <button class="btn">End Turn</button>
    </div>
  `;

  const intent = root.querySelector<HTMLElement>('#intent')!;
  const toggle = root.querySelector<HTMLButtonElement>('#toggle-pixel')!;

  return {
    setIntentPosition(x, y) {
      intent.style.transform = `translate(${x}px, ${y}px) translate(-50%, -100%)`;
    },
    onTogglePixel(handler) {
      toggle.addEventListener('click', handler);
      window.addEventListener('keydown', (e) => {
        if (e.key === 'p' || e.key === 'P') handler();
      });
    },
    setPixelLabel(on) {
      toggle.textContent = `Pixel: ${on ? 'ON' : 'OFF'}`;
    },
  };
}
