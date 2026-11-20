import type { EnemyDef } from '../core/types.ts';

/** Market Street rivals (GDD §6.5). Tony is the tutorial opponent. */
export const ENEMIES: Record<string, EnemyDef> = {
  tony: {
    id: 'tony',
    name: 'Tony',
    title: 'street noodle cook',
    confidence: 30,
    pattern: [
      { kind: 'attack', label: 'Prepping', amount: 6 },
      { kind: 'attack', label: 'Prepping', amount: 8 },
      { kind: 'attackBlock', label: 'Stir-fry', amount: 5, block: 5 },
      { kind: 'block', label: 'Composed', amount: 8 },
    ],
  },
};
