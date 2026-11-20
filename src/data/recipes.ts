import type { RecipeDef } from '../core/types.ts';

/** Basics Cookbook (GDD §6.3). Other books are added with the Shop. */
export const RECIPES: Record<string, RecipeDef> = {
  omelette: {
    id: 'omelette', name: 'Omelette', book: 'basics',
    requires: [{ tag: 'PROTEIN' }, { tag: 'FAT' }, { tag: 'VEGGIE' }],
    effects: [{ kind: 'pressure', amount: 10 }, { kind: 'composure', amount: 5 }],
    hype: 25, text: '10 Pressure, 5 Composure',
  },
  toast: {
    id: 'toast', name: 'Toast', book: 'basics',
    requires: [{ tag: 'CARB' }, { tag: 'FAT' }],
    effects: [{ kind: 'pressure', amount: 6 }, { kind: 'draw', amount: 1 }],
    hype: 25, text: '6 Pressure, draw 1',
  },
  freshSalad: {
    id: 'freshSalad', name: 'Fresh Salad', book: 'basics',
    requires: [{ tag: 'VEGGIE' }, { tag: 'VEGGIE' }],
    // "Remove 1 debuff" joins once statuses exist (GDD §4.7).
    effects: [{ kind: 'composure', amount: 8 }],
    hype: 25, text: '8 Composure',
  },
};

export const BOOKS: Record<string, { name: string; recipes: string[] }> = {
  basics: { name: 'Basics Cookbook', recipes: ['omelette', 'toast', 'freshSalad'] },
};
