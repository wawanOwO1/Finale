/** Shared data shapes for the duel. Pure data: no DOM, no Three.js (GDD §9). */

export type Tag = 'PROTEIN' | 'CARB' | 'VEGGIE' | 'FAT' | 'DAIRY' | 'SPICE' | 'SAUCE';

/**
 * Composable effects (GDD §9): cards, recipes and later Kitchen Tools all use this list.
 * `amount` is the base value; recipes add the Plate's total Quality to their first effect.
 */
export type Effect =
  | { kind: 'pressure'; amount: number }
  | { kind: 'composure'; amount: number }
  | { kind: 'heal'; amount: number }
  | { kind: 'draw'; amount: number }
  | { kind: 'hype'; amount: number };

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

export type Intent =
  | { kind: 'attack'; label: string; amount: number }
  | { kind: 'block'; label: string; amount: number }
  | { kind: 'attackBlock'; label: string; amount: number; block: number };

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
