import { CLEANSE_ORDER } from '../data/statuses.ts';
import { EventBus, type DuelEvents } from './events.ts';
import { bestDish, checkRecipes, inOrder, plateQuality, type RecipeCheck } from './recipes.ts';
import { createRng, shuffle, type Rng } from './rng.ts';
import type { CardDef, CardInstance, Effect, EnemyDef, Intent, RecipeDef, StatusId, Statuses } from './types.ts';

/**
 * Duel state machine (GDD §4). Pure logic: the UI calls play / serve / endTurn and
 * re-renders from the public state; visuals subscribe to `bus` events.
 */

export const MAX_HEAT = 3;
export const HAND_SIZE = 5;
export const PLATE_SIZE = 5;
export const SERVE_COST = 1;
export const MAX_HYPE = 100;
/** Ingredients placed in Recipe Book order (GDD revision 22 Nov). */
export const PERFECT_ORDER_MULT = 1.5;

/** Signature Dish (GDD §4.5): appears in hand when Hype is full, once per duel. */
export const SIGNATURE_CARD: CardDef = {
  id: 'signature',
  name: 'Signature Dish',
  type: 'technique',
  cost: 0,
  effects: [],
  text: 'Your next Serve has ×2 effect. Retain. Once per duel.',
  retain: true,
  exhaust: true,
  special: 'signature',
};

export type Side = 'player' | 'enemy';

export interface Fighter {
  confidence: number;
  maxConfidence: number;
  composure: number;
  statuses: Statuses;
}

export type Phase = 'player' | 'won' | 'lost';

export interface DuelOptions {
  deck: CardDef[];
  enemy: EnemyDef;
  recipes: RecipeDef[];
  /** Carried between duels in a run (GDD §4.1). */
  confidence?: number;
  maxConfidence?: number;
  /** Starting Hype (Lucky Apron, dev testing). */
  hype?: number;
  seed?: number;
}

export type Check = { ok: true } | { ok: false; reason: string };

export class Duel {
  readonly bus = new EventBus<DuelEvents>();
  readonly player: Fighter & { heat: number };
  readonly enemy: Fighter & { def: EnemyDef };
  readonly recipes: RecipeDef[];

  drawPile: CardInstance[] = [];
  hand: CardInstance[] = [];
  discard: CardInstance[] = [];
  plate: CardInstance[] = [];
  /** Cards removed from this duel (played Signature Dish). */
  exhausted: CardInstance[] = [];

  hype = 0;
  turn = 0;
  phase: Phase = 'player';
  servedThisTurn = false;
  /** Signature Dish card was handed out (once per duel). */
  signatureGiven = false;
  /** Signature Dish played; the next Serve is doubled. */
  signatureArmed = false;
  /** Newest last; the HUD shows the tail. */
  log: string[] = [];

  private intentIndex = 0;
  private nextUid = 0;
  private rng: Rng;

  constructor(opts: DuelOptions) {
    this.rng = createRng(opts.seed ?? Date.now());
    const maxConf = opts.maxConfidence ?? 60;
    this.player = { confidence: opts.confidence ?? maxConf, maxConfidence: maxConf, composure: 0, heat: 0, statuses: {} };
    this.enemy = {
      def: opts.enemy,
      confidence: opts.enemy.confidence,
      maxConfidence: opts.enemy.confidence,
      composure: 0,
      statuses: {},
    };
    this.recipes = opts.recipes;
    this.drawPile = shuffle(opts.deck.map((def) => this.instance(def)), this.rng);
    this.startPlayerTurn();
    // Starting Hype goes through addHype so a full meter hands out the Signature Dish.
    if (opts.hype) this.addHype(opts.hype);
  }

  // ---------------------------------------------------------------- queries

  get intent(): Intent {
    const p = this.enemy.def.pattern;
    return p[this.intentIndex % p.length];
  }

  get recipeCheck(): RecipeCheck {
    return checkRecipes(this.recipes, this.plate);
  }

  fighter(side: Side): Fighter {
    return side === 'player' ? this.player : this.enemy;
  }

  /**
   * Pressure after statuses: (base + attacker Focus) × 0.75 if attacker Flustered
   * × 1.5 if defender Rattled, rounded down. Used for attacks and for intent previews.
   */
  pressureFrom(attacker: Side, base: number): number {
    const a = this.fighter(attacker).statuses;
    const d = this.fighter(attacker === 'player' ? 'enemy' : 'player').statuses;
    let v = base + (a.focus ?? 0);
    if (a.flustered) v *= 0.75;
    if (d.rattled) v *= 1.5;
    return Math.max(0, Math.floor(v));
  }

  canPlay(uid: number): Check {
    if (this.phase !== 'player') return { ok: false, reason: 'The duel is over.' };
    const card = this.hand.find((c) => c.uid === uid);
    if (!card) return { ok: false, reason: 'Card is not in hand.' };
    if (card.def.cost > this.player.heat) return { ok: false, reason: 'Not enough Heat.' };
    if (card.def.type === 'ingredient' && this.plate.length >= PLATE_SIZE) {
      return { ok: false, reason: 'The Plate is full.' };
    }
    return { ok: true };
  }

  canServe(): Check {
    if (this.phase !== 'player') return { ok: false, reason: 'The duel is over.' };
    if (this.servedThisTurn) return { ok: false, reason: 'Already served this turn.' };
    if (this.plate.length === 0) return { ok: false, reason: 'The Plate is empty.' };
    if (this.player.heat < SERVE_COST) return { ok: false, reason: 'Not enough Heat.' };
    return { ok: true };
  }

  // ---------------------------------------------------------------- actions

  play(uid: number): Check {
    const check = this.canPlay(uid);
    if (!check.ok) return check;
    const i = this.hand.findIndex((c) => c.uid === uid);
    const [card] = this.hand.splice(i, 1);
    this.player.heat -= card.def.cost;

    if (card.def.type === 'ingredient') {
      this.plate.push(card);
      this.say(`${card.def.name} goes on the Plate.`);
    } else {
      (card.def.exhaust ? this.exhausted : this.discard).push(card);
      this.say(`Apis uses ${card.def.name}.`);
    }
    if (card.def.special === 'signature') {
      this.signatureArmed = true;
      this.say('Signature Dish ready! Next Serve ×2.');
    }
    this.bus.emit('card_played', { card });
    this.applyEffects(card.def.effects, { bonus: 0, mult: 1 });
    this.changed();
    return { ok: true };
  }

  /**
   * Serve the whole Prep Board. The Recipe Book is closed during a duel, so by default
   * (`undefined`) the game cooks the best matching dish (see bestDish). Tests may force a
   * recipe id, or `null` for an Improvised Dish.
   */
  serve(recipeId?: string | null): Check {
    const check = this.canServe();
    if (!check.ok) return check;

    let recipe: RecipeDef | null = null;
    if (recipeId === undefined) {
      recipe = bestDish(this.recipes, this.plate)?.recipe ?? null;
    } else if (recipeId !== null) {
      recipe = this.recipeCheck.ready.find((r) => r.id === recipeId) ?? null;
      if (!recipe) return { ok: false, reason: 'That recipe does not match the Plate.' };
    }
    const perfect = recipe ? inOrder(recipe, this.plate) : false;

    this.player.heat -= SERVE_COST;
    this.servedThisTurn = true;
    const served = this.plate;
    this.plate = [];
    const quality = plateQuality(served);
    const enemyBefore = this.enemy.confidence + this.enemy.composure;

    // Effect multiplier: Perfect Order ×1.5, Signature Dish ×2, Burnt ×0.5 (all stack).
    let mult = perfect ? PERFECT_ORDER_MULT : 1;
    const signature = this.signatureArmed;
    if (signature) {
      mult *= 2;
      this.signatureArmed = false;
    }
    const burnt = !!this.player.statuses.burnt;
    if (burnt) {
      mult *= 0.5;
      this.addStatus('player', 'burnt', -1);
      this.say('Burnt! This Serve is halved.');
    }

    const dishName = recipe ? recipe.name : 'Improvised Dish';
    if (signature) this.bus.emit('signature_served', { dish: dishName });
    // Announced before the effects so the dish reveal shows ahead of the damage numbers.
    this.bus.emit('dish_revealed', { recipe, perfect, signature, burnt });

    if (recipe) {
      this.say(`SERVE! ${recipe.name} (+${quality} Quality)${perfect ? ' Perfect Order!' : ''}${signature ? ' ×2' : ''}`);
      // Recipe effect = base value + total Plate Quality (GDD §4.4), on the headline effect.
      this.applyEffects(recipe.effects, { bonus: quality, mult });
    } else {
      this.say(`Improvised Dish: ${served.length} ingredients.${signature ? ' ×2' : ''}`);
      this.applyEffects([{ kind: 'pressure', amount: 2 * served.length }], { bonus: 0, mult });
    }
    // The Signature Dish spends the crowd; otherwise a recipe Serve builds Hype.
    if (signature) this.hype = 0;
    else if (recipe) this.addHype(recipe.hype);

    this.discard.push(...served);
    const dealt = enemyBefore - (this.enemy.confidence + this.enemy.composure);
    this.bus.emit('dish_served', { recipe, pressure: dealt, quality, count: served.length });
    this.changed();
    return { ok: true };
  }

  endTurn(): Check {
    if (this.phase !== 'player') return { ok: false, reason: 'The duel is over.' };
    // Hand is discarded except Retain cards; the Plate stays (GDD §4.2 step 4).
    const kept = this.hand.filter((c) => c.def.retain);
    this.discard.push(...this.hand.filter((c) => !c.def.retain));
    this.hand = kept;
    this.endOfTurnDecay('player');
    this.enemyTurn();
    if (this.phase === 'player') this.startPlayerTurn();
    this.changed();
    return { ok: true };
  }

  // ---------------------------------------------------------------- turn flow

  private startPlayerTurn(): void {
    this.turn++;
    this.player.composure = 0;
    this.servedThisTurn = false;
    this.tickSpicy('player');
    if (this.phase !== 'player') return;
    this.player.heat = MAX_HEAT;
    const inspired = this.player.statuses.inspired ?? 0;
    if (inspired) this.addStatus('player', 'inspired', -inspired);
    this.draw(HAND_SIZE + inspired);
    this.bus.emit('turn_started', { turn: this.turn });
  }

  private enemyTurn(): void {
    // Composure fades at the start of its owner's turn (GDD §4.1).
    this.enemy.composure = 0;
    this.tickSpicy('enemy');
    if (this.phase !== 'player') return;

    const intent = this.intent;
    const name = this.enemy.def.name;
    this.say(`${name}: ${intent.label}!`);
    if (intent.attack !== undefined) this.dealPressure('player', this.pressureFrom('enemy', intent.attack));
    if (this.phase !== 'player') return;
    if (intent.block) this.gainComposure('enemy', intent.block);
    if (intent.status) {
      const side: Side = intent.status.target === 'player' ? 'player' : 'enemy';
      this.addStatus(side, intent.status.id, intent.status.amount);
    }
    this.bus.emit('enemy_acted', { intent });
    this.intentIndex++;
    this.endOfTurnDecay('enemy');
  }

  /** Spicy: lose X Confidence (ignores Composure), then X − 1. */
  private tickSpicy(side: Side): void {
    const x = this.fighter(side).statuses.spicy ?? 0;
    if (!x) return;
    this.say(`${side === 'player' ? 'Apis' : this.enemy.def.name} feels the burn: −${x}`);
    this.loseConfidence(side, x, 'spicy');
    this.addStatus(side, 'spicy', -1);
  }

  /** Flustered and Rattled count down at the end of their owner's turn. */
  private endOfTurnDecay(side: Side): void {
    for (const id of ['flustered', 'rattled'] as const) {
      if (this.fighter(side).statuses[id]) this.addStatus(side, id, -1);
    }
  }

  // ---------------------------------------------------------------- effects

  /** `bonus` is added to the first effect's amount (recipe Quality); `mult` scales it all. */
  private applyEffects(effects: Effect[], { bonus, mult }: { bonus: number; mult: number }): void {
    effects.forEach((e, i) => {
      if (this.phase !== 'player') return;
      const scaled = (n: number) => Math.floor((n + (i === 0 ? bonus : 0)) * mult);
      switch (e.kind) {
        case 'pressure': this.dealPressure('enemy', this.pressureFrom('player', scaled(e.amount))); break;
        case 'composure': this.gainComposure('player', scaled(e.amount)); break;
        case 'heal': this.heal(scaled(e.amount)); break;
        case 'draw': this.draw(e.amount); break;
        case 'hype': this.addHype(e.amount); break;
        case 'status':
          this.addStatus(e.target === 'self' ? 'player' : 'enemy', e.status, Math.max(1, scaled(e.amount)));
          break;
        case 'cleanse': this.cleanse(e.amount); break;
      }
    });
  }

  /** Pressure hits Composure first, then Confidence. `amount` already includes statuses. */
  private dealPressure(target: Side, amount: number): void {
    const f = this.fighter(target);
    const blocked = Math.min(f.composure, amount);
    f.composure -= blocked;
    this.bus.emit('pressure_dealt', { target, amount, blocked });
    this.loseConfidence(target, amount - blocked, 'pressure');
  }

  private loseConfidence(target: Side, amount: number, source: 'pressure' | 'spicy'): void {
    const f = this.fighter(target);
    if (amount > 0) this.bus.emit('confidence_lost', { target, amount: Math.min(amount, f.confidence), source });
    f.confidence = Math.max(0, f.confidence - amount);
    if (f.confidence === 0 && this.phase === 'player') {
      this.phase = target === 'enemy' ? 'won' : 'lost';
      this.say(target === 'enemy' ? `${this.enemy.def.name} gives up!` : 'Apis loses heart...');
      this.bus.emit('duel_ended', { winner: target === 'enemy' ? 'player' : 'enemy' });
    }
  }

  private addStatus(side: Side, id: StatusId, delta: number): void {
    const s = this.fighter(side).statuses;
    const v = (s[id] ?? 0) + delta;
    if (v > 0) s[id] = v;
    else delete s[id];
    if (delta > 0) this.bus.emit('status_applied', { target: side, status: id, amount: delta });
  }

  private cleanse(count: number): void {
    for (let n = 0; n < count; n++) {
      const id = CLEANSE_ORDER.find((s) => this.player.statuses[s]);
      if (!id) return;
      delete this.player.statuses[id];
      this.say(`Cleansed ${id}.`);
    }
  }

  private gainComposure(target: Side, amount: number): void {
    this.fighter(target).composure += amount;
    this.bus.emit('composure_gained', { target, amount });
  }

  private heal(amount: number): void {
    this.player.confidence = Math.min(this.player.maxConfidence, this.player.confidence + amount);
  }

  private addHype(amount: number): void {
    this.hype = Math.min(MAX_HYPE, this.hype + amount);
    if (this.hype >= MAX_HYPE && !this.signatureGiven) {
      this.signatureGiven = true;
      this.hand.push(this.instance(SIGNATURE_CARD));
      this.say('The crowd goes wild! Signature Dish unlocked!');
      this.bus.emit('signature_ready', {});
    }
  }

  private draw(n: number): void {
    for (let i = 0; i < n; i++) {
      if (this.drawPile.length === 0) {
        if (this.discard.length === 0) return;
        this.drawPile = shuffle(this.discard, this.rng);
        this.discard = [];
      }
      this.hand.push(this.drawPile.pop()!);
    }
  }

  private instance(def: CardDef): CardInstance {
    return { uid: this.nextUid++, def };
  }

  private say(line: string): void {
    this.log.push(line);
    if (this.log.length > 30) this.log.shift();
  }

  private changed(): void {
    this.bus.emit('changed', {});
  }
}
