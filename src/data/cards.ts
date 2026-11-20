import type { CardDef, Tag } from '../core/types.ts';

const ing = (
  id: string, name: string, tag: Tag, cost: number, quality: number,
  extra: Pick<CardDef, 'effects' | 'text'> = { effects: [], text: '' },
): CardDef => ({
  id, name, type: 'ingredient', cost, tags: [tag], quality,
  effects: extra.effects,
  text: `Quality ${quality}${extra.text ? `. ${extra.text}` : ''}`,
});

/**
 * Starter cards (GDD §6.1) + the reward-pool cards (§6.2) whose effects exist so far.
 * Still missing (need their own mechanics): Cream, Olive Oil, Sauté, Taste Test,
 * Plating Art, Second Helping, Clean Station.
 */
export const CARDS: Record<string, CardDef> = {
  // ---- starter
  egg: ing('egg', 'Egg', 'PROTEIN', 0, 1),
  bread: ing('bread', 'Bread', 'CARB', 0, 1),
  tomato: ing('tomato', 'Tomato', 'VEGGIE', 0, 1),
  butter: ing('butter', 'Butter', 'FAT', 0, 1),
  quickChop: {
    id: 'quickChop', name: 'Quick Chop', type: 'technique', cost: 1,
    effects: [{ kind: 'pressure', amount: 6 }], text: '6 Pressure',
  },
  deepBreath: {
    id: 'deepBreath', name: 'Deep Breath', type: 'technique', cost: 1,
    effects: [{ kind: 'composure', amount: 5 }], text: '5 Composure',
  },

  // ---- reward pool: ingredients
  chicken: ing('chicken', 'Chicken', 'PROTEIN', 1, 2),
  beef: ing('beef', 'Beef', 'PROTEIN', 1, 2, { effects: [], text: 'Key for Classic Steak' }),
  fish: ing('fish', 'Fish', 'PROTEIN', 1, 2, { effects: [{ kind: 'composure', amount: 3 }], text: '3 Composure' }),
  rice: ing('rice', 'Rice', 'CARB', 0, 1, { effects: [{ kind: 'draw', amount: 1 }], text: 'Draw 1' }),
  pasta: ing('pasta', 'Pasta', 'CARB', 1, 2),
  onion: ing('onion', 'Onion', 'VEGGIE', 0, 1, {
    effects: [{ kind: 'status', status: 'flustered', amount: 1, target: 'enemy' }], text: 'Rival Flustered 1',
  }),
  mushroom: ing('mushroom', 'Mushroom', 'VEGGIE', 1, 2),
  chili: ing('chili', 'Chili', 'SPICE', 0, 1, {
    effects: [{ kind: 'status', status: 'spicy', amount: 2, target: 'enemy' }], text: 'Rival Spicy 2',
  }),
  garlic: ing('garlic', 'Garlic', 'SPICE', 0, 1, { effects: [{ kind: 'composure', amount: 2 }], text: '2 Composure' }),
  cheese: ing('cheese', 'Cheese', 'DAIRY', 1, 2),
  stock: ing('stock', 'Stock', 'SAUCE', 0, 1),
  tomatoSauce: ing('tomatoSauce', 'Tomato Sauce', 'SAUCE', 1, 2),

  // ---- reward pool: techniques
  flambe: {
    id: 'flambe', name: 'Flambé', type: 'technique', cost: 2,
    effects: [{ kind: 'pressure', amount: 12 }, { kind: 'hype', amount: 10 }], text: '12 Pressure, Hype +10',
  },
  miseEnPlace: {
    id: 'miseEnPlace', name: 'Mise en Place', type: 'technique', cost: 0,
    effects: [{ kind: 'draw', amount: 2 }], text: 'Draw 2',
  },
  stareDown: {
    id: 'stareDown', name: 'Stare Down', type: 'technique', cost: 1,
    effects: [{ kind: 'status', status: 'rattled', amount: 2, target: 'enemy' }], text: 'Rival Rattled 2',
  },
  crowdPleaser: {
    id: 'crowdPleaser', name: 'Crowd Pleaser', type: 'technique', cost: 1,
    effects: [{ kind: 'hype', amount: 20 }], text: 'Hype +20',
  },
};

export const STARTER_DECK: string[] = [
  'egg', 'egg', 'bread', 'tomato', 'butter',
  'quickChop', 'quickChop', 'quickChop',
  'deepBreath', 'deepBreath',
];

/** Graybox test deck (?deck=dev): starter plus status cards, to exercise every system. */
export const DEV_DECK: string[] = [
  ...STARTER_DECK,
  'chili', 'chili', 'onion', 'beef', 'garlic', 'stareDown', 'crowdPleaser', 'crowdPleaser', 'flambe',
];
