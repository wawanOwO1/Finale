import type { EnemyDef } from '../core/types.ts';

/** Market Street rivals (GDD §6.5). Intent icons are derived from what an intent does. */
export const ENEMIES: Record<string, EnemyDef> = {
  /** Tutorial opponent: plain attacks and blocks. */
  tony: {
    id: 'tony',
    name: 'Tony',
    title: 'Street Noodle Cook',
    confidence: 30,
    pattern: [
      { label: 'Prepping', attack: 6 },
      { label: 'Prepping', attack: 8 },
      { label: 'Stir-fry', attack: 5, block: 5 },
      { label: 'Composed', block: 8 },
    ],
  },
  /** Taunts often (Flustered). */
  rosa: {
    id: 'rosa',
    name: 'Rosa',
    title: 'Taco Truck Queen',
    confidence: 38,
    pattern: [
      { label: 'Taunt', attack: 4, status: { id: 'flustered', amount: 2, target: 'player' } },
      { label: 'Prepping', attack: 9 },
      { label: 'Salsa Shield', block: 7 },
      { label: 'Taunt', status: { id: 'rattled', amount: 2, target: 'player' } },
      { label: 'Prepping', attack: 11 },
    ],
  },
};
