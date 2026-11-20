import { MAX_HEAT, MAX_HYPE, PERFECT_ORDER_MULT, PLATE_SIZE, SERVE_COST, type Duel } from '../core/duel';
import type { CardDef, CardInstance, Intent, RecipeDef, Requirement, StatusId, Statuses } from '../core/types';
import { CARDS } from '../data/cards';
import { STATUSES } from '../data/statuses';
import { attachCardDrag } from './drag';
import { icon, injectIconSprite } from './icons';
import { cardKeywords, cardRole, highlight, KEYWORDS, type Keyword } from './keywords';

/**
 * Duel HUD (GDD §7.2), rendered from Duel state. Clean graybox: SVG sprite icons only,
 * keyword tooltips on hover, cards dragged onto the Prep Board or up to play.
 */
export interface Point {
  x: number;
  y: number;
}

export interface Hud {
  bind(duel: Duel, rivalName: string): void;
  /** Screen positions of the 3D anchors, updated every frame. */
  setAnchors(a: { rival: Point; player: Point; board: Point }): void;
  /** Show the Recipe Book before the duel; resolves when the player closes it. */
  showCookbook(recipes: RecipeDef[]): Promise<void>;
  onTogglePixel(handler: () => void): void;
  onRestart(handler: () => void): void;
  setPixelLabel(on: boolean): void;
}

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => `&#${c.charCodeAt(0)};`);

// ------------------------------------------------------------------ small renderers

function tipAttrs(title: string, text: string, ic = ''): string {
  return `data-tip="${esc(title)}" data-tip-text="${esc(text)}" data-tip-icon="${ic}"`;
}

function statusHtml(statuses: Statuses): string {
  return (Object.entries(statuses) as [StatusId, number][])
    .map(([id, n]) => {
      const s = STATUSES[id];
      return `<span class="status ${s.debuff ? 'debuff' : 'buff'}" ${tipAttrs(
        `${s.name} ${n}`, s.text.replace(/X/g, String(n)), s.icon,
      )}>${icon(s.icon)}<b>${n}</b></span>`;
    })
    .join('');
}

function intentHtml(i: Intent, d: Duel): string {
  const parts: string[] = [];
  const said: string[] = [];
  if (i.attack !== undefined) {
    const v = d.pressureFrom('enemy', i.attack);
    parts.push(`<span class="intent-part attack">${icon('pressure')}<b>${v}</b></span>`);
    said.push(`deal ${v} Pressure`);
  }
  if (i.block) {
    parts.push(`<span class="intent-part block">${icon('composure')}<b>${i.block}</b></span>`);
    said.push(`gain ${i.block} Composure`);
  }
  if (i.status) {
    const s = STATUSES[i.status.id];
    const cls = i.status.target === 'player' ? 'debuff' : 'buff';
    parts.push(`<span class="intent-part ${cls}">${icon(s.icon)}<b>${i.status.amount}</b></span>`);
    said.push(`${i.status.target === 'player' ? 'give you' : 'gain'} ${s.name} ${i.status.amount}`);
  }
  const text = `${d.enemy.def.name} will ${said.join(', ')}.`;
  return `<div class="intent-pill" ${tipAttrs(`Intent: ${i.label}`, text, 'taunt')}>${parts.join('')}</div>`;
}

function tagOf(def: CardDef): string {
  return def.tags?.[0] ?? 'technique';
}

function cardHtml(c: CardInstance, playable: boolean, style: string, dealt: boolean, tipsLeft: boolean): string {
  const d = c.def;
  const art = d.special === 'signature' ? 'crown' : d.type === 'ingredient' ? tagOf(d) : 'technique';
  const typeLine = d.special === 'signature' ? 'Signature' : d.type === 'ingredient' ? `Ingredient · ${tagOf(d)}` : 'Technique';
  const tips = [cardRole(d), ...cardKeywords(d)].map(tipBox).join('');
  const cls = ['card', d.type, d.special ?? '', `tag-${tagOf(d)}`, playable ? '' : 'disabled', dealt ? 'deal' : '', tipsLeft ? 'tips-left' : '']
    .filter(Boolean).join(' ');
  return `
    <div class="${cls}" data-uid="${c.uid}" style="${style}">
      <div class="card-cost">${d.cost}</div>
      <div class="card-name">${esc(d.name)}</div>
      <div class="card-art">${icon(art)}</div>
      <div class="card-type">${typeLine}</div>
      <div class="card-text">${highlight(d.text)}</div>
      <div class="card-tips">${tips}</div>
    </div>`;
}

function tipBox(k: Keyword): string {
  return `<div class="tip-box"><div class="tip-title">${icon(k.icon)}${esc(k.name)}</div><div class="tip-text">${highlight(k.text)}</div></div>`;
}

function reqChip(r: Requirement): string {
  if ('card' in r) {
    const def = CARDS[r.card];
    return `<span class="req key tag-${tagOf(def)}">${icon(tagOf(def))}${esc(def.name)}</span>`;
  }
  return `<span class="req tag-${r.tag}">${icon(r.tag)}${r.tag}</span>`;
}

// ------------------------------------------------------------------ HUD

export function createHud(root: HTMLElement): Hud {
  injectIconSprite();
  root.innerHTML = `
    <div class="topbar">
      <div class="venue"><span class="venue-name">Market Street</span><span class="venue-sub" id="venue-sub"></span></div>
      <div class="hype-meter" ${tipAttrs('Hype', KEYWORDS.Hype.text, 'hype')}>
        ${icon('hype', 'c-hype')}<span class="hype-label">HYPE</span>
        <div class="hype-track"><div class="hype-fill" id="hype-fill"></div><div class="hype-ticks"></div></div>
        <span class="hype-value" id="hype-value"></span>
      </div>
      <button class="icon-btn" id="toggle-pixel" ${tipAttrs('Pixel filter', 'Toggle the low-res pixel look. Shortcut: P.', 'pixel')}>${icon('pixel')}</button>
    </div>

    <div class="rival" id="rival">
      <div id="intent"></div>
      <div class="rival-name" id="rival-name"></div>
      <div class="hp">
        <div class="block-badge" id="enemy-block" ${tipAttrs('Composure', KEYWORDS.Composure.text, 'composure')}></div>
        <div class="hp-bar"><div class="hp-fill" id="enemy-fill"></div><span id="enemy-conf"></span></div>
      </div>
      <div class="statuses" id="enemy-statuses"></div>
    </div>

    <div class="board" id="board">
      <div class="board-head">
        <span>Prep Board</span>
        <span class="board-count" id="board-count"></span>
      </div>
      <div class="slots" id="slots">
        ${Array.from({ length: PLATE_SIZE }, (_, i) => `${i ? `<span class="slot-arrow">${icon('arrow')}</span>` : ''}<div class="slot" data-slot="${i}"><span class="slot-n">${i + 1}</span></div>`).join('')}
      </div>
      <button class="serve-btn" id="serve" ${tipAttrs('Serve', KEYWORDS.Serve.text, 'serve')}></button>
    </div>

    <div class="player-hud">
      <div class="statuses" id="player-statuses"></div>
      <div class="player-row">
        <div class="hp-badge" ${tipAttrs('Confidence', KEYWORDS.Confidence.text, 'confidence')}>
          ${icon('confidence', 'hp-badge-bg')}
          <div class="hp-badge-value" id="player-conf"></div>
        </div>
        <div class="block-badge big" id="player-block" ${tipAttrs('Composure', KEYWORDS.Composure.text, 'composure')}></div>
      </div>
    </div>

    <div class="heat-orb" id="heat" ${tipAttrs('Heat', KEYWORDS.Heat.text, 'heat')}></div>
    <div class="pile draw-pile" id="draw-pile" ${tipAttrs('Draw pile', 'Cards you will draw. Shuffled from the discard pile when empty.', 'draw')}></div>
    <div class="pile discard-pile" id="discard-pile" ${tipAttrs('Discard pile', 'Played and discarded cards. Shuffled back when the draw pile runs out.', 'discard')}></div>

    <div class="hand" id="hand"></div>
    <div class="play-zone" id="play-zone"><span>Release to play</span></div>
    <button class="end-turn" id="end-turn">End Turn</button>

    <div class="floaters" id="floaters"></div>
    <div class="dish-banner hidden" id="dish-banner"></div>
    <div class="toast hidden" id="toast"></div>
    <div class="tooltip hidden" id="tooltip"></div>

    <div class="cutin hidden" id="cutin">
      <div class="cutin-lines"></div>
      <div class="cutin-text">
        <div class="cutin-sfx">SIGNATURE DISH!!</div>
        <div class="cutin-dish" id="cutin-dish"></div>
      </div>
    </div>

    <div class="modal hidden" id="cookbook"></div>

    <div class="modal hidden" id="overlay">
      <div class="modal-box end-box">
        <div class="end-title" id="overlay-title"></div>
        <div class="end-text" id="overlay-text"></div>
        <button class="primary-btn" id="restart">Duel again</button>
      </div>
    </div>
  `;

  const $ = <T extends HTMLElement = HTMLElement>(id: string) => root.querySelector<T>(`#${id}`)!;
  const toggle = $<HTMLButtonElement>('toggle-pixel');
  const serveBtn = $<HTMLButtonElement>('serve');
  const handEl = $('hand');
  const boardEl = $('board');
  const slots = [...root.querySelectorAll<HTMLElement>('.slot')];
  let duel: Duel | null = null;
  let anchors = { rival: { x: 0, y: 0 }, player: { x: 0, y: 0 }, board: { x: 0, y: 0 } };
  let prevHand = new Set<number>();
  let placedUid = -1;

  // ---------------------------------------------------------------- tooltips
  const tooltip = $('tooltip');
  root.addEventListener('pointerover', (e) => {
    const el = (e.target as HTMLElement).closest<HTMLElement>('[data-tip]');
    if (!el || document.body.classList.contains('dragging')) return tooltip.classList.add('hidden');
    tooltip.innerHTML = tipBox({ name: el.dataset.tip!, text: el.dataset.tipText!, icon: el.dataset.tipIcon || 'hype' });
    tooltip.classList.remove('hidden');
    const r = el.getBoundingClientRect();
    const t = tooltip.getBoundingClientRect();
    const below = r.top < window.innerHeight / 2;
    const x = Math.min(window.innerWidth - t.width - 8, Math.max(8, r.left + r.width / 2 - t.width / 2));
    const y = below ? r.bottom + 8 : r.top - t.height - 8;
    tooltip.style.transform = `translate(${x}px, ${y}px)`;
  });
  root.addEventListener('pointerout', (e) => {
    if ((e.target as HTMLElement).closest('[data-tip]')) tooltip.classList.add('hidden');
  });

  // ---------------------------------------------------------------- feedback
  let toastTimer = 0;
  function toast(text: string): void {
    const el = $('toast');
    el.textContent = text;
    el.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = window.setTimeout(() => el.classList.add('hidden'), 1400);
  }

  function floatText(at: Point, html: string, cls: string, delay = 0): void {
    const el = document.createElement('div');
    el.className = `floater ${cls}`;
    el.innerHTML = html;
    el.style.left = `${at.x + (Math.random() - 0.5) * 40}px`;
    el.style.top = `${at.y}px`;
    el.style.animationDelay = `${delay}ms`;
    $('floaters').append(el);
    el.addEventListener('animationend', () => el.remove());
  }

  let bannerTimer = 0;
  function showDish(recipe: RecipeDef | null, perfect: boolean, signature: boolean, burnt: boolean): void {
    const el = $('dish-banner');
    const tags = [
      perfect ? `<span class="dish-tag gold">${icon('check')}Perfect Order x${PERFECT_ORDER_MULT}</span>` : '',
      signature ? `<span class="dish-tag gold">${icon('crown')}Signature x2</span>` : '',
      burnt ? `<span class="dish-tag bad">${icon('burnt')}Burnt -50%</span>` : '',
      recipe && !perfect ? `<span class="dish-tag">Out of order</span>` : '',
    ].join('');
    el.innerHTML = `<div class="dish-kicker">${recipe ? 'Dish served' : 'No recipe matched'}</div>
      <div class="dish-name">${esc(recipe ? recipe.name : 'Improvised Dish')}</div><div class="dish-tags">${tags}</div>`;
    const b = boardEl.getBoundingClientRect();
    el.style.left = `${b.left + b.width / 2}px`;
    el.style.top = `${b.top - 12}px`;
    el.classList.remove('hidden', 'play');
    void el.offsetWidth;
    el.classList.add('play');
    clearTimeout(bannerTimer);
    bannerTimer = window.setTimeout(() => el.classList.add('hidden'), 1900);
  }

  let cutinTimer = 0;
  function playCutIn(dish: string): void {
    const el = $('cutin');
    $('cutin-dish').textContent = dish;
    el.classList.remove('hidden', 'play');
    void el.offsetWidth;
    el.classList.add('play');
    clearTimeout(cutinTimer);
    cutinTimer = window.setTimeout(() => el.classList.add('hidden'), 1600);
  }

  // ---------------------------------------------------------------- input
  attachCardDrag({
    hand: handEl,
    board: boardEl,
    playZone: $('play-zone'),
    canPlay: (uid) => duel?.canPlay(uid) ?? { ok: false, reason: '' },
    cardOf: (uid) => duel?.hand.find((c) => c.uid === uid)?.def,
    nextSlot: () => slots[Math.min(duel?.plate.length ?? 0, PLATE_SIZE - 1)],
    targetOf: (def) => {
      const hitsRival = def.effects.some((e) => e.kind === 'pressure' || (e.kind === 'status' && e.target === 'enemy'));
      return hitsRival ? anchors.rival : anchors.player;
    },
    play: (uid) => {
      placedUid = uid;
      duel?.play(uid);
    },
    reject: (reason) => {
      toast(reason);
      if (reason.includes('Heat')) {
        const h = $('heat');
        h.classList.remove('flash');
        void h.offsetWidth;
        h.classList.add('flash');
      }
    },
    hint: () => toast('Drag a card to play it'),
  });

  serveBtn.addEventListener('click', () => duel?.serve());
  $('end-turn').addEventListener('click', () => duel?.endTurn());

  // ---------------------------------------------------------------- render
  function render(): void {
    if (!duel) return;
    const d = duel;
    const live = d.phase === 'player';

    // Rival
    $('intent').innerHTML = live ? intentHtml(d.intent, d) : '';
    $('rival-name').innerHTML = `${esc(d.enemy.def.name)}<small>${esc(d.enemy.def.title)}</small>`;
    $('enemy-fill').style.width = `${(100 * d.enemy.confidence) / d.enemy.maxConfidence}%`;
    $('enemy-conf').textContent = `${d.enemy.confidence} / ${d.enemy.maxConfidence}`;
    blockBadge($('enemy-block'), d.enemy.composure);
    $('enemy-statuses').innerHTML = statusHtml(d.enemy.statuses);

    // Player
    $('player-conf').innerHTML = `${d.player.confidence}<small>/${d.player.maxConfidence}</small>`;
    blockBadge($('player-block'), d.player.composure);
    $('player-statuses').innerHTML = statusHtml(d.player.statuses);
    $('heat').innerHTML = `${icon('heat', 'heat-bg')}<span>${d.player.heat}<small>/${MAX_HEAT}</small></span>`;
    $('heat').classList.toggle('empty', d.player.heat === 0);
    $('draw-pile').innerHTML = `${icon('draw')}<b>${d.drawPile.length}</b>`;
    $('discard-pile').innerHTML = `${icon('discard')}<b>${d.discard.length}</b>`;

    // Hype
    $('hype-fill').style.width = `${(100 * d.hype) / MAX_HYPE}%`;
    $('hype-fill').classList.toggle('full', d.hype >= MAX_HYPE || d.signatureArmed);
    $('hype-value').textContent = `${d.hype}`;

    // Hand: fanned, new cards dealt in with a stagger.
    const n = d.hand.length;
    let dealIndex = 0;
    handEl.innerHTML = d.hand
      .map((c, i) => {
        const k = i - (n - 1) / 2;
        const isNew = !prevHand.has(c.uid);
        const style = `--rot:${(k * 3.5).toFixed(1)}deg;--lift:${(k * k * 0.3).toFixed(2)}em;--z:${i};--deal:${isNew ? dealIndex++ * 70 : 0}ms`;
        return cardHtml(c, live && d.canPlay(c.uid).ok, style, isNew, k > 0.5);
      })
      .join('');
    prevHand = new Set(d.hand.map((c) => c.uid));

    // Prep Board: ingredients in placement order. The book is closed: no recipe hints.
    slots.forEach((slot, i) => {
      const c = d.plate[i];
      slot.classList.toggle('filled', !!c);
      slot.classList.toggle('next', i === d.plate.length);
      slot.innerHTML = c
        ? `<div class="tile tag-${tagOf(c.def)}${c.uid === placedUid ? ' pop' : ''}" ${tipAttrs(c.def.name, `${c.def.tags?.join(', ')} · Quality ${c.def.quality}`, tagOf(c.def))}>
             ${icon(tagOf(c.def))}<span class="tile-name">${esc(c.def.name)}</span>
             <span class="tile-q">${'<i></i>'.repeat(c.def.quality ?? 0)}</span></div>`
        : `<span class="slot-n">${i + 1}</span>`;
    });
    placedUid = -1;
    $('board-count').textContent = `${d.plate.length}/${PLATE_SIZE}`;
    boardEl.classList.toggle('hidden', !live);

    const serveCheck = d.canServe();
    serveBtn.disabled = !serveCheck.ok;
    serveBtn.classList.toggle('armed', d.signatureArmed);
    serveBtn.innerHTML = `${icon('serve')}<span>Serve${d.signatureArmed ? ' x2' : ''}</span><span class="cost">${SERVE_COST}${icon('heat')}</span>`;
    $<HTMLButtonElement>('end-turn').disabled = !live;

    // End of duel
    const over = !live;
    $('overlay').classList.toggle('hidden', !over);
    if (over) {
      $('overlay-title').textContent = d.phase === 'won' ? 'Victory' : 'Defeat';
      $('overlay').classList.toggle('won', d.phase === 'won');
      $('overlay-text').textContent =
        d.phase === 'won'
          ? `${d.enemy.def.name} gives up in ${d.turn} turns. Confidence left: ${d.player.confidence}.`
          : `${d.enemy.def.name} out-cooked you this time.`;
    }
  }

  function blockBadge(el: HTMLElement, value: number): void {
    el.innerHTML = `${icon('composure', 'block-bg')}<span>${value}</span>`;
    el.classList.toggle('hidden', value === 0);
  }

  // ---------------------------------------------------------------- cookbook
  function showCookbook(recipes: RecipeDef[]): Promise<void> {
    const el = $('cookbook');
    $('overlay').classList.add('hidden');
    el.innerHTML = `
      <div class="modal-box book-box">
        <div class="book-head">${icon('book')}<div><div class="book-title">Recipe Book</div>
          <div class="book-sub">Memorize it. The book stays closed during the duel.</div></div></div>
        <div class="book-rule">Ingredients placed on the Prep Board <b>in this order</b> cook a
          <span class="kw">Perfect Order</span> for x${PERFECT_ORDER_MULT} effect. Any order still cooks the dish.</div>
        <div class="book-list">
          ${recipes
            .map(
              (r) => `<div class="book-row">
                <div class="book-name">${esc(r.name)}</div>
                <div class="book-seq">${r.requires.map(reqChip).join(`<span class="seq-arrow">${icon('arrow')}</span>`)}</div>
                <div class="book-effect">${highlight(r.text)} <small>+ Quality</small></div>
              </div>`,
            )
            .join('')}
        </div>
        <button class="primary-btn" id="close-book">Close the book and duel</button>
      </div>`;
    el.classList.remove('hidden');
    return new Promise((resolve) => {
      el.querySelector('#close-book')!.addEventListener('click', () => {
        el.classList.add('hidden');
        resolve();
      });
    });
  }

  return {
    bind(next, rivalName) {
      duel = next;
      prevHand = new Set();
      $('venue-sub').textContent = `vs ${rivalName}`;
      next.bus.on('changed', render);
      next.bus.on('signature_served', ({ dish }) => playCutIn(dish));
      next.bus.on('dish_revealed', (e) => showDish(e.recipe, e.perfect, e.signature, e.burnt));
      next.bus.on('confidence_lost', (e) => {
        const at = e.target === 'enemy' ? anchors.rival : anchors.player;
        floatText(at, `-${e.amount}`, `dmg ${e.source}`);
      });
      next.bus.on('pressure_dealt', (e) => {
        if (e.blocked > 0) floatText(e.target === 'enemy' ? anchors.rival : anchors.player, `${icon('composure')}${e.blocked}`, 'blocked');
      });
      next.bus.on('composure_gained', (e) => {
        floatText(e.target === 'enemy' ? anchors.rival : anchors.player, `+${icon('composure')}${e.amount}`, 'gain', 120);
      });
      next.bus.on('status_applied', (e) => {
        const s = STATUSES[e.status];
        floatText(e.target === 'enemy' ? anchors.rival : anchors.player, `${icon(s.icon)}${s.name} ${e.amount}`, s.debuff ? 'debuff' : 'buff', 240);
      });
      render();
    },
    setAnchors(a) {
      anchors = a;
      $('rival').style.transform = `translate(${a.rival.x}px, ${a.rival.y}px) translate(-50%, -100%)`;
      boardEl.style.transform = `translate(${a.board.x}px, ${a.board.y}px) translate(-50%, -100%)`;
    },
    showCookbook,
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
      toggle.classList.toggle('on', on);
    },
  };
}
