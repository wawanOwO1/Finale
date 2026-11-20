/** Shared data shapes for the duel. Pure data: no DOM, no Three.js (GDD §9). */

export type Tag = 'PROTEIN' | 'CARB' | 'VEGGIE' | 'FAT' | 'DAIRY' | 'SPICE' | 'SAUCE';

/** Statuses (GDD §4.7). Definitions and tooltips live in data/statuses.ts. */
export type StatusId = 'spicy' | 'flustered' | 'rattled' | 'burnt' | 'focus' | 'inspired';

export type Statuses = Partial<Record<StatusId, number>>;

/**
 * Composable effects (GDD §9): cards, recipes and later Kitchen Tools all use this list.
 * `amount` is the base value; recipes add the Plate's total Quality to their first effect.
 * `target` is seen from the player: 'enemy' = the rival, 'self' = Apis.
 */
export type Effect =
  | { kind: 'pressure'; amount: number }
  | { kind: 'composure'; amount: number }
  | { kind: 'heal'; amount: number }
  | { kind: 'draw'; amount: number }
  | { kind: 'hype'; amount: number }
  | { kind: 'status'; status: StatusId; amount: number; target: 'self' | 'enemy' }
  /** Remove debuffs from Apis (Fresh Salad). */
  | { kind: 'cleanse'; amount: number };

export interface CardDef {
  id: string;
  name: string;
  type: 'ingredient' | 'technique';
  cost: number;
  /** Ingredients only. */
  tags?: Tag[];
  /** Ingredients only, 1–3 (GDD §4.4). */
  quality?: number;
  /** Ingredient: applied when placed on the Plate. Technique: applied when played. */
  effects: Effect[];
  text: string;
  /** Stays in hand at End Turn. */
  retain?: boolean;
  /** Removed from the duel once played instead of going to the discard pile. */
  exhaust?: boolean;
  /** Special behaviour that is not a plain effect. */
  special?: 'signature';
}

/** A recipe slot: a tag (any ingredient carrying it) or a key ingredient by card id. */
export type Requirement = { tag: Tag } | { card: string };

export interface RecipeDef {
  id: string;
  name: string;
  book: string;
  requires: Requirement[];
  effects: Effect[];
  /** Hype gained when served (GDD §4.4: +25, more for higher tiers). */
  hype: number;
  text: string;
}

/** What the rival will do on its next turn, shown over its head (GDD §4.6). */
export interface Intent {
  label: string;
  attack?: number;
  block?: number;
  /** 'player' = debuff on Apis (Taunt), 'self' = buff on the rival. */
  status?: { id: StatusId; amount: number; target: 'player' | 'self' };
}

export interface EnemyDef {
  id: string;
  name: string;
  title: string;
  confidence: number;
  /** Intents cycle in order (simple pattern AI; gimmicks come later). */
  pattern: Intent[];
}

/** A card instance in a pile. `uid` tells two copies of the same card apart. */
export interface CardInstance {
  uid: number;
  def: CardDef;
}
