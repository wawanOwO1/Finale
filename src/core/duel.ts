import { EventBus, type DuelEvents } from './events.ts';
import { checkRecipes, plateQuality, type RecipeCheck } from './recipes.ts';
import { createRng, shuffle, type Rng } from './rng.ts';
import type { CardDef, CardInstance, Effect, EnemyDef, Intent, RecipeDef } from './types.ts';

/**
 * Duel state machine (GDD §4). Pure logic: the UI calls play / serve / endTurn and
 * re-renders from the public state; visuals subscribe to `bus` events.
 */

export const MAX_HEAT = 3;
export const HAND_SIZE = 5;
export const PLATE_SIZE = 5;
export const SERVE_COST = 1;
export const MAX_HYPE = 100;

export interface Fighter {
  confidence: number;
  maxConfidence: number;
  composure: number;
}

export type Phase = 'player' | 'won' | 'lost';

export interface DuelOptions {
  deck: CardDef[];
  enemy: EnemyDef;
  recipes: RecipeDef[];
  /** Carried between duels in a run (GDD §4.1). */
  confidence?: number;
  maxConfidence?: number;
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

  hype = 0;
  turn = 0;
  phase: Phase = 'player';
  servedThisTurn = false;
  /** Newest last; the HUD shows the tail. */
  log: string[] = [];

  private intentIndex = 0;
  private rng: Rng;

  constructor(opts: DuelOptions) {
    this.rng = createRng(opts.seed ?? Date.now());
    const maxConf = opts.maxConfidence ?? 60;
    this.player = { confidence: opts.confidence ?? maxConf, maxConfidence: maxConf, composure: 0, heat: 0 };
    this.enemy = {
      def: opts.enemy,
      confidence: opts.enemy.confidence,
      maxConfidence: opts.enemy.confidence,
      composure: 0,
    };
    this.recipes = opts.recipes;
    this.drawPile = shuffle(opts.deck.map((def, uid) => ({ uid, def })), this.rng);
    this.startPlayerTurn();
  }

  // ---------------------------------------------------------------- queries

  get intent(): Intent {
    const p = this.enemy.def.pattern;
    return p[this.intentIndex % p.length];
  }

  get recipeCheck(): RecipeCheck {
    return checkRecipes(this.recipes, this.plate);
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
      this.discard.push(card);
      this.say(`Apis uses ${card.def.name}.`);
    }
    this.bus.emit('card_played', { card });
    this.applyEffects(card.def.effects, 0);
    this.changed();
    return { ok: true };
  }

  /**
   * Serve the whole Plate. `recipeId` picks among ready recipes (GDD §4.3: the player
   * chooses); `null` serves it as an Improvised Dish.
   */
  serve(recipeId: string | null): Check {
    const check = this.canServe();
    if (!check.ok) return check;

    let recipe: RecipeDef | null = null;
    if (recipeId !== null) {
      recipe = this.recipeCheck.ready.find((r) => r.id === recipeId) ?? null;
      if (!recipe) return { ok: false, reason: 'That recipe does not match the Plate.' };
    }

    this.player.heat -= SERVE_COST;
    this.servedThisTurn = true;
    const served = this.plate;
    this.plate = [];
    const quality = plateQuality(served);
    const enemyBefore = this.enemy.confidence + this.enemy.composure;

    if (recipe) {
      this.say(`SERVE! ${recipe.name} (+${quality} Quality)`);
      // Recipe effect = base value + total Plate Quality (GDD §4.4), on the headline effect.
      this.applyEffects(recipe.effects, quality);
      this.addHype(recipe.hype);
    } else {
      const pressure = 2 * served.length;
      this.say(`Improvised Dish: ${served.length} ingredients.`);
      this.applyEffects([{ kind: 'pressure', amount: pressure }], 0);
    }

    this.discard.push(...served);
    const dealt = enemyBefore - (this.enemy.confidence + this.enemy.composure);
    this.bus.emit('dish_served', { recipe, pressure: dealt, quality, count: served.length });
    this.changed();
    return { ok: true };
  }

  endTurn(): Check {
    if (this.phase !== 'player') return { ok: false, reason: 'The duel is over.' };
    // Hand is discarded; the Plate stays (GDD §4.2 step 4).
    this.discard.push(...this.hand);
    this.hand = [];
    this.enemyTurn();
    if (this.phase === 'player') this.startPlayerTurn();
    this.changed();
    return { ok: true };
  }

  // ---------------------------------------------------------------- turn flow

  private startPlayerTurn(): void {
    this.turn++;
    this.player.composure = 0;
    this.player.heat = MAX_HEAT;
    this.servedThisTurn = false;
    this.draw(HAND_SIZE);
    this.bus.emit('turn_started', { turn: this.turn });
  }

  private enemyTurn(): void {
    // Composure fades at the start of its owner's turn (GDD §4.1).
    this.enemy.composure = 0;
    const intent = this.intent;
    const name = this.enemy.def.name;
    if (intent.kind === 'attack' || intent.kind === 'attackBlock') {
      this.say(`${name}: ${intent.label}!`);
      this.dealPressure('player', intent.amount);
    }
    if (intent.kind === 'block') {
      this.say(`${name} is ${intent.label}.`);
      this.gainComposure('enemy', intent.amount);
    } else if (intent.kind === 'attackBlock') {
      this.gainComposure('enemy', intent.block);
    }
    this.bus.emit('enemy_acted', { intent });
    this.intentIndex++;
  }

  // ---------------------------------------------------------------- effects

  /** `bonus` is added to the first effect's amount (recipe Quality). */
  private applyEffects(effects: Effect[], bonus: number): void {
    effects.forEach((e, i) => {
      if (this.phase !== 'player') return;
      const amount = e.amount + (i === 0 ? bonus : 0);
      switch (e.kind) {
        case 'pressure': this.dealPressure('enemy', amount); break;
        case 'composure': this.gainComposure('player', amount); break;
        case 'heal': this.heal(amount); break;
        case 'draw': this.draw(amount); break;
        case 'hype': this.addHype(amount); break;
      }
    });
  }

  private dealPressure(target: 'player' | 'enemy', amount: number): void {
    const f = target === 'player' ? this.player : this.enemy;
    const blocked = Math.min(f.composure, amount);
    f.composure -= blocked;
    f.confidence = Math.max(0, f.confidence - (amount - blocked));
    this.bus.emit('pressure_dealt', { target, amount, blocked });

    if (f.confidence === 0) {
      this.phase = target === 'enemy' ? 'won' : 'lost';
      this.say(target === 'enemy' ? `${this.enemy.def.name} gives up!` : 'Apis loses heart...');
      this.bus.emit('duel_ended', { winner: target === 'enemy' ? 'player' : 'enemy' });
    }
  }

  private gainComposure(target: 'player' | 'enemy', amount: number): void {
    (target === 'player' ? this.player : this.enemy).composure += amount;
    this.bus.emit('composure_gained', { target, amount });
  }

  private heal(amount: number): void {
    this.player.confidence = Math.min(this.player.maxConfidence, this.player.confidence + amount);
  }

  private addHype(amount: number): void {
    this.hype = Math.min(MAX_HYPE, this.hype + amount);
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

  private say(line: string): void {
    this.log.push(line);
    if (this.log.length > 30) this.log.shift();
  }

  private changed(): void {
    this.bus.emit('changed', {});
  }
}
