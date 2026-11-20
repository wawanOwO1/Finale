import type { RecipeDef } from '../core/types.ts';

/**
 * All jam-version recipes (GDD §6.3). `requires` is in Recipe Book order: placing the
 * ingredients on the Prep Board in that order is a Perfect Order (×1.5).
 * The first effect also gets + total board Quality.
 */
export const RECIPES: Record<string, RecipeDef> = {
  // ---- Basics Cookbook (starter)
  omelette: {
    id: 'omelette', name: 'Omelette', book: 'basics',
    requires: [{ tag: 'FAT' }, { tag: 'PROTEIN' }, { tag: 'VEGGIE' }],
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
    effects: [{ kind: 'composure', amount: 8 }, { kind: 'cleanse', amount: 1 }],
    hype: 25, text: '8 Composure, remove 1 debuff',
  },

  // ---- Grill Master's Notes
  classicSteak: {
    id: 'classicSteak', name: 'Classic Steak', book: 'grill',
    requires: [{ tag: 'FAT' }, { card: 'beef' }, { tag: 'SPICE' }],
    effects: [{ kind: 'pressure', amount: 20 }],
    hype: 35, text: '20 Pressure',
  },
  skewers: {
    id: 'skewers', name: 'Skewers', book: 'grill',
    requires: [{ tag: 'PROTEIN' }, { tag: 'SPICE' }],
    effects: [{ kind: 'pressure', amount: 8 }, { kind: 'status', status: 'focus', amount: 1, target: 'self' }],
    hype: 30, text: '8 Pressure, Focus 1',
  },
  mixedGrill: {
    id: 'mixedGrill', name: 'Mixed Grill', book: 'grill',
    requires: [{ tag: 'FAT' }, { tag: 'PROTEIN' }, { tag: 'PROTEIN' }],
    effects: [{ kind: 'pressure', amount: 16 }, { kind: 'status', status: 'rattled', amount: 1, target: 'enemy' }],
    hype: 30, text: '16 Pressure, Rival Rattled 1',
  },

  // ---- Spice Route Journal
  arrabbiata: {
    id: 'arrabbiata', name: 'Arrabbiata', book: 'spice',
    requires: [{ tag: 'SAUCE' }, { tag: 'SPICE' }, { tag: 'CARB' }],
    effects: [{ kind: 'pressure', amount: 8 }, { kind: 'status', status: 'spicy', amount: 4, target: 'enemy' }],
    hype: 30, text: '8 Pressure, Rival Spicy 4',
  },
  hotWings: {
    id: 'hotWings', name: 'Hot Wings', book: 'spice',
    requires: [{ tag: 'PROTEIN' }, { tag: 'SPICE' }, { tag: 'SPICE' }],
    effects: [{ kind: 'pressure', amount: 6 }, { kind: 'status', status: 'spicy', amount: 6, target: 'enemy' }],
    hype: 30, text: '6 Pressure, Rival Spicy 6',
  },

  // ---- Comfort Food Diary
  warmSoup: {
    id: 'warmSoup', name: 'Warm Soup', book: 'comfort',
    requires: [{ tag: 'SAUCE' }, { tag: 'PROTEIN' }, { tag: 'VEGGIE' }],
    effects: [{ kind: 'heal', amount: 5 }, { kind: 'composure', amount: 8 }],
    hype: 30, text: 'Recover 5 Confidence, 8 Composure',
  },
  macAndCheese: {
    id: 'macAndCheese', name: 'Mac & Cheese', book: 'comfort',
    requires: [{ tag: 'CARB' }, { tag: 'FAT' }, { tag: 'DAIRY' }],
    effects: [{ kind: 'pressure', amount: 8 }, { kind: 'composure', amount: 8 }],
    hype: 30, text: '8 Pressure, 8 Composure',
  },
  mushroomRisotto: {
    id: 'mushroomRisotto', name: 'Mushroom Risotto', book: 'comfort',
    requires: [{ tag: 'CARB' }, { tag: 'VEGGIE' }, { tag: 'DAIRY' }],
    effects: [{ kind: 'composure', amount: 10 }, { kind: 'status', status: 'inspired', amount: 1, target: 'self' }],
    hype: 30, text: '10 Composure, Inspired 1',
  },
};

export const BOOKS: Record<string, { name: string; recipes: string[] }> = {
  basics: { name: 'Basics Cookbook', recipes: ['omelette', 'toast', 'freshSalad'] },
  grill: { name: "Grill Master's Notes", recipes: ['classicSteak', 'skewers', 'mixedGrill'] },
  spice: { name: 'Spice Route Journal', recipes: ['arrabbiata', 'hotWings'] },
  comfort: { name: 'Comfort Food Diary', recipes: ['warmSoup', 'macAndCheese', 'mushroomRisotto'] },
};
