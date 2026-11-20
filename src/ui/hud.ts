import { MAX_HEAT, MAX_HYPE, PLATE_SIZE, SERVE_COST, type Duel } from '../core/duel';
import { missingCount } from '../core/recipes';
import type { CardInstance, Intent, RecipeDef, Requirement } from '../core/types';

/**
 * Graybox HUD (GDD §7.2), rendered from Duel state. Confidence badge bottom-left,
 * hand at the bottom, Plate panel above the player's counter, rival intent over its head.
 */
export interface Hud {
  bind(duel: Duel): void;
  render(): void;
  /** Move the rival intent label to a screen position (pixels). */
  setIntentPosition(x: number, y: number): void;
  /** Move the Plate panel to a screen position (pixels). */
  setPlatePosition(x: number, y: number): void;
  onTogglePixel(handler: () => void): void;
  onRestart(handler: () => void): void;
  setPixelLabel(on: boolean): void;
}

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => `&#${c.charCodeAt(0)};`);

function intentText(i: Intent): string {
  switch (i.kind) {
    case 'attack': return `🔪 ${i.label} · ${i.amount}`;
    case 'block': return `🛡️ ${i.label} · ${i.amount}`;
    case 'attackBlock': return `🔪 ${i.label} · ${i.amount} + 🛡️ ${i.block}`;
  }
}

function reqText(r: Requirement): string {
  return 'card' in r ? r.card : r.tag;
}

/** Which requirement labels are still unmet (for the "almost" hint). */
function missingLabels(recipe: RecipeDef, plate: CardInstance[]): string[] {
  // Try dropping each requirement: the one whose removal completes the recipe is missing.
  return recipe.requires
    .filter((_, i) => missingCount({ ...recipe, requires: recipe.requires.filter((__, j) => j !== i) }, plate) === 0)
    .map(reqText)
    .filter((v, i, a) => a.indexOf(v) === i);
}

function cardHtml(c: CardInstance, playable: boolean): string {
  const d = c.def;
  const type = d.type === 'technique' ? 'Technique' : (d.tags ?? []).join(' · ');
  return `
    <div class="card ${d.type}${playable ? '' : ' disabled'}" data-uid="${c.uid}">
      <div class="card-cost">${d.cost}</div>
      <div class="card-name">${esc(d.name)}</div>
      <div class="card-art"></div>
      <div class="card-type">${type}</div>
      <div class="card-text">${esc(d.text)}</div>
    </div>`;
}

export function createHud(root: HTMLElement): Hud {
  root.innerHTML = `
    <div class="top-bar">
      <span class="title">FINALE</span>
      <span class="district">Market Street · Duel 1</span>
      <div class="hype" title="Hype: fills on recipe Serves. Signature Dish unlocks at 100.">
        <span>HYPE</span><div class="hype-bar"><div class="hype-fill" id="hype-fill"></div></div>
      </div>
      <button class="btn small" id="toggle-pixel" title="Toggle pixel filter (P)">Pixel: OFF</button>
    </div>

    <div class="log" id="log"></div>

    <div class="intent" id="intent">
      <div class="intent-name" id="enemy-name"></div>
      <div class="intent-bubble" id="intent-bubble"></div>
      <div class="bar"><div class="bar-fill" id="enemy-fill"></div><span id="enemy-conf"></span></div>
      <div class="chip composure" id="enemy-composure"></div>
    </div>

    <div class="plate-panel" id="plate-panel">
      <div class="plate-items" id="plate-items"></div>
      <div class="recipes" id="recipes"></div>
    </div>

    <div class="badge-area">
      <div class="badge">
        <div class="badge-value" id="player-conf"></div>
        <div class="badge-label">Confidence</div>
      </div>
      <div class="chips">
        <div class="chip composure" id="player-composure"></div>
        <div class="chip heat" id="heat"></div>
        <div class="chip tips">💰 0</div>
      </div>
    </div>

    <div class="piles" id="piles"></div>
    <div class="hand" id="hand"></div>

    <div class="actions">
      <button class="btn serve" id="serve"></button>
      <button class="btn" id="end-turn">End Turn</button>
    </div>

    <div class="overlay hidden" id="overlay">
      <div class="overlay-box">
        <div class="overlay-title" id="overlay-title"></div>
        <div class="overlay-text" id="overlay-text"></div>
        <button class="btn serve" id="restart">Duel again</button>
      </div>
    </div>
  `;

  const $ = <T extends HTMLElement = HTMLElement>(id: string) => root.querySelector<T>(`#${id}`)!;
  const intent = $('intent');
  const platePanel = $('plate-panel');
  const toggle = $<HTMLButtonElement>('toggle-pixel');
  const serveBtn = $<HTMLButtonElement>('serve');
  let duel: Duel | null = null;

  // ---- input (event delegation so re-rendering doesn't drop listeners)
  $('hand').addEventListener('click', (e) => {
    const el = (e.target as HTMLElement).closest<HTMLElement>('.card');
    if (duel && el) duel.play(Number(el.dataset.uid));
  });
  $('recipes').addEventListener('click', (e) => {
    const el = (e.target as HTMLElement).closest<HTMLElement>('[data-recipe]');
    if (duel && el) duel.serve(el.dataset.recipe || null);
  });
  serveBtn.addEventListener('click', () => {
    if (!duel) return;
    const ready = duel.recipeCheck.ready;
    if (ready.length <= 1) duel.serve(ready[0]?.id ?? null);
  });
  $('end-turn').addEventListener('click', () => duel?.endTurn());

  function render(): void {
    if (!duel) return;
    const d = duel;
    const { ready, almost } = d.recipeCheck;
    const serveCheck = d.canServe();

    // Rival
    $('enemy-name').textContent = `${d.enemy.def.name}, ${d.enemy.def.title}`;
    $('intent-bubble').textContent = d.phase === 'player' ? intentText(d.intent) : '😵 Gave up';
    $('enemy-fill').style.width = `${(100 * d.enemy.confidence) / d.enemy.maxConfidence}%`;
    $('enemy-conf').textContent = `Confidence ${d.enemy.confidence}/${d.enemy.maxConfidence}`;
    const ec = $('enemy-composure');
    ec.textContent = `🛡️ ${d.enemy.composure}`;
    ec.classList.toggle('hidden', d.enemy.composure === 0);

    // Player
    $('player-conf').innerHTML = `${d.player.confidence}<small>/${d.player.maxConfidence}</small>`;
    $('player-composure').textContent = `🛡️ ${d.player.composure}`;
    $('heat').textContent = `🔥 ${d.player.heat}/${MAX_HEAT}`;
    $('hype-fill').style.width = `${(100 * d.hype) / MAX_HYPE}%`;
    $('piles').textContent = `Draw ${d.drawPile.length} · Discard ${d.discard.length} · Turn ${d.turn}`;

    // Hand
    $('hand').innerHTML = d.hand.map((c) => cardHtml(c, d.canPlay(c.uid).ok)).join('');

    // Plate + recipe hints (GDD §4.3: ready and one-short, live)
    $('plate-items').innerHTML =
      d.plate.length === 0
        ? `<span class="muted">Plate empty · 0/${PLATE_SIZE}</span>`
        : d.plate.map((c) => `<span class="plate-item">${esc(c.def.name)} <b>Q${c.def.quality ?? 0}</b></span>`).join('') +
          `<span class="muted">${d.plate.length}/${PLATE_SIZE}</span>`;
    const canPick = serveCheck.ok;
    $('recipes').innerHTML = [
      ...ready.map(
        (r) => `<button class="recipe ready" data-recipe="${r.id}" ${canPick ? '' : 'disabled'}
          title="${esc(r.text)} (+ Plate Quality)">✔ ${esc(r.name)} <small>${esc(r.text)}</small></button>`,
      ),
      ...almost.map(
        (r) => `<div class="recipe almost">${esc(r.name)} <small>needs ${missingLabels(r, d.plate).join(' / ')}</small></div>`,
      ),
    ].join('');
    platePanel.classList.toggle('hidden', d.phase !== 'player');

    // Serve button
    if (ready.length > 1) {
      serveBtn.innerHTML = `CHOOSE A RECIPE ↖`;
      serveBtn.disabled = true;
    } else {
      const what = ready[0] ? ready[0].name : d.plate.length ? 'Improvised' : '';
      serveBtn.innerHTML = `SERVE <small>${SERVE_COST}🔥${what ? ` · ${esc(what)}` : ''}</small>`;
      serveBtn.disabled = !serveCheck.ok;
      serveBtn.title = serveCheck.ok ? '' : serveCheck.reason;
    }
    $<HTMLButtonElement>('end-turn').disabled = d.phase !== 'player';

    // Log
    $('log').innerHTML = d.log.slice(-5).map((l) => `<div>${esc(l)}</div>`).join('');

    // End overlay
    const over = d.phase !== 'player';
    $('overlay').classList.toggle('hidden', !over);
    if (over) {
      $('overlay-title').textContent = d.phase === 'won' ? 'VICTORY!' : 'DEFEAT...';
      $('overlay-text').textContent =
        d.phase === 'won'
          ? `${d.enemy.def.name} gives up in ${d.turn} turns. Confidence left: ${d.player.confidence}.`
          : `${d.enemy.def.name} out-cooked you this time.`;
    }
  }

  return {
    bind(next) {
      duel = next;
      next.bus.on('changed', render);
      render();
    },
    render,
    setIntentPosition(x, y) {
      intent.style.transform = `translate(${x}px, ${y}px) translate(-50%, -100%)`;
    },
    setPlatePosition(x, y) {
      platePanel.style.transform = `translate(${x}px, ${y}px) translate(-50%, -100%)`;
    },
    onTogglePixel(handler) {
      toggle.addEventListener('click', handler);
      window.addEventListener('keydown', (e) => {
        if (e.key === 'p' || e.key === 'P') handler();
      });
    },
    onRestart(handler) {
      $('restart').addEventListener('click', handler);
    },
    setPixelLabel(on) {
      toggle.textContent = `Pixel: ${on ? 'ON' : 'OFF'}`;
    },
  };
}
