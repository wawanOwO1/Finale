import type { Check } from '../core/duel';
import type { CardDef } from '../core/types';

/**
 * Drag-and-drop for the hand. Ingredients drop on the Prep Board and fly into the next
 * slot; techniques are dragged up out of the hand and fly at their target. A dropped card
 * that lands nowhere glides back. The ghost card tilts with the cursor's motion.
 */
export interface DragOptions {
  hand: HTMLElement;
  board: HTMLElement;
  playZone: HTMLElement;
  canPlay(uid: number): Check;
  cardOf(uid: number): CardDef | undefined;
  /** Slot element the next ingredient lands in. */
  nextSlot(): HTMLElement;
  /** Screen point a technique flies to (rival or Apis). */
  targetOf(def: CardDef): { x: number; y: number };
  play(uid: number): void;
  reject(reason: string): void;
  /** Card clicked without dragging. */
  hint(): void;
}

interface DragState {
  uid: number;
  def: CardDef;
  el: HTMLElement;
  startX: number;
  startY: number;
  started: boolean;
  ghost?: HTMLElement;
  w: number;
  h: number;
  offX: number;
  offY: number;
  /** Card center now and where it started (for the glide back). */
  cx: number;
  cy: number;
  homeX: number;
  homeY: number;
  tilt: number;
  lastX: number;
}

const DRAG_THRESHOLD = 6;

export function attachCardDrag(o: DragOptions): void {
  let s: DragState | null = null;
  let busy = false;

  const transformFor = (cx: number, cy: number, w: number, h: number, rot: number, scale: number) =>
    `translate(${cx - w / 2}px, ${cy - h / 2}px) rotate(${rot}deg) scale(${scale})`;

  o.hand.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 || busy) return;
    const el = (e.target as HTMLElement).closest<HTMLElement>('.card');
    if (!el) return;
    const uid = Number(el.dataset.uid);
    const def = o.cardOf(uid);
    if (!def) return;
    e.preventDefault();
    const check = o.canPlay(uid);
    if (!check.ok) {
      el.animate(
        [{ translate: '0 0' }, { translate: '-0.4em 0' }, { translate: '0.4em 0' }, { translate: '-0.2em 0' }, { translate: '0 0' }],
        { duration: 260, easing: 'ease-out' },
      );
      o.reject(check.reason);
      return;
    }
    s = {
      uid, def, el, startX: e.clientX, startY: e.clientY, started: false,
      w: 0, h: 0, offX: 0, offY: 0, cx: 0, cy: 0, homeX: 0, homeY: 0, tilt: 0, lastX: e.clientX,
    };
  });

  function begin(d: DragState, e: PointerEvent): void {
    const r = d.el.getBoundingClientRect();
    d.w = d.el.offsetWidth;
    d.h = d.el.offsetHeight;
    d.homeX = r.left + r.width / 2;
    d.homeY = r.top + r.height / 2;
    d.offX = e.clientX - d.homeX;
    d.offY = e.clientY - d.homeY;

    const ghost = d.el.cloneNode(true) as HTMLElement;
    ghost.querySelector('.card-tips')?.remove();
    ghost.classList.add('ghost');
    ghost.classList.remove('deal', 'tips-left');
    ghost.style.width = `${d.w}px`;
    ghost.style.height = `${d.h}px`;
    o.hand.parentElement!.append(ghost);
    d.ghost = ghost;
    d.el.classList.add('placeholder');
    document.body.classList.add('dragging', `drag-${d.def.type}`);
    d.started = true;
  }

  function overBoard(e: PointerEvent): boolean {
    const r = o.board.getBoundingClientRect();
    const pad = 40;
    return e.clientX > r.left - pad && e.clientX < r.right + pad && e.clientY > r.top - pad && e.clientY < r.bottom + pad;
  }

  const inPlayZone = (e: PointerEvent) => e.clientY < window.innerHeight * 0.66;

  window.addEventListener('pointermove', (e) => {
    if (!s) return;
    if (!s.started) {
      if (Math.hypot(e.clientX - s.startX, e.clientY - s.startY) < DRAG_THRESHOLD) return;
      begin(s, e);
    }
    // Tilt follows horizontal speed, eased so it settles when the cursor stops.
    const target = Math.max(-18, Math.min(18, (e.clientX - s.lastX) * 1.2));
    s.tilt += (target - s.tilt) * 0.35;
    s.lastX = e.clientX;
    s.cx = e.clientX - s.offX;
    s.cy = e.clientY - s.offY;
    s.ghost!.style.transform = transformFor(s.cx, s.cy, s.w, s.h, s.tilt, 1.08);

    const ingredient = s.def.type === 'ingredient';
    o.board.classList.toggle('drop-hover', ingredient && overBoard(e));
    o.playZone.classList.toggle('active', !ingredient && inPlayZone(e));
  });

  function finish(d: DragState): void {
    d.ghost?.remove();
    d.el.classList.remove('placeholder');
    document.body.classList.remove('dragging', 'drag-ingredient', 'drag-technique');
    o.board.classList.remove('drop-hover');
    o.playZone.classList.remove('active');
    busy = false;
  }

  function fly(d: DragState, to: Keyframe, ms: number, easing: string, then: () => void): void {
    busy = true;
    const from = { transform: d.ghost!.style.transform, opacity: 1 };
    const anim = d.ghost!.animate([from, to], { duration: ms, easing, fill: 'forwards' });
    anim.finished.then(() => {
      then();
      finish(d);
    });
  }

  window.addEventListener('pointerup', (e) => {
    const d = s;
    s = null;
    if (!d) return;
    if (!d.started) return o.hint();

    if (d.def.type === 'ingredient' && overBoard(e)) {
      // Shrink into the next board slot.
      const r = o.nextSlot().getBoundingClientRect();
      const scale = r.height / d.h;
      fly(
        d,
        { transform: transformFor(r.left + r.width / 2, r.top + r.height / 2, d.w, d.h, 0, scale), opacity: 0.9 },
        200, 'cubic-bezier(.3,.8,.4,1)',
        () => o.play(d.uid),
      );
    } else if (d.def.type !== 'ingredient' && inPlayZone(e)) {
      // Whoosh toward the rival (attacks, debuffs) or Apis (Composure, draw, Hype).
      const t = o.targetOf(d.def);
      fly(
        d,
        { transform: transformFor(t.x, t.y, d.w, d.h, d.tilt * 2, 0.3), opacity: 0 },
        240, 'cubic-bezier(.5,0,.8,.4)',
        () => o.play(d.uid),
      );
    } else {
      fly(d, { transform: transformFor(d.homeX, d.homeY, d.w, d.h, 0, 1), opacity: 1 }, 180, 'ease-out', () => {});
    }
  });

  window.addEventListener('pointercancel', () => {
    if (s?.started) finish(s);
    s = null;
  });
}
