import type { CardDef } from '../core/types.ts';

/** Starter cards (GDD §6.1). The reward pool (§6.2) is added once statuses exist. */
export const CARDS: Record<string, CardDef> = {
  egg: { id: 'egg', name: 'Egg', type: 'ingredient', cost: 0, tags: ['PROTEIN'], quality: 1, effects: [], text: 'Quality 1' },
  bread: { id: 'bread', name: 'Bread', type: 'ingredient', cost: 0, tags: ['CARB'], quality: 1, effects: [], text: 'Quality 1' },
  tomato: { id: 'tomato', name: 'Tomato', type: 'ingredient', cost: 0, tags: ['VEGGIE'], quality: 1, effects: [], text: 'Quality 1' },
  butter: { id: 'butter', name: 'Butter', type: 'ingredient', cost: 0, tags: ['FAT'], quality: 1, effects: [], text: 'Quality 1' },
  quickChop: {
    id: 'quickChop', name: 'Quick Chop', type: 'technique', cost: 1,
    effects: [{ kind: 'pressure', amount: 6 }], text: '6 Pressure',
  },
  deepBreath: {
    id: 'deepBreath', name: 'Deep Breath', type: 'technique', cost: 1,
    effects: [{ kind: 'composure', amount: 5 }], text: '5 Composure',
  },
};

export const STARTER_DECK: string[] = [
  'egg', 'egg', 'bread', 'tomato', 'butter',
  'quickChop', 'quickChop', 'quickChop',
  'deepBreath', 'deepBreath',
];
