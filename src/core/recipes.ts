import type { CardInstance, RecipeDef, Requirement } from './types.ts';

function fits(req: Requirement, card: CardInstance): boolean {
  return 'card' in req ? card.def.id === req.card : (card.def.tags ?? []).includes(req.tag);
}

/**
 * How many requirements are left unmet when each Plate ingredient may fill at most one slot.
 * Small sizes (≤6 slots, ≤6 ingredients), so a plain backtracking search is fine and handles
 * multi-tag ingredients and duplicates like VEGGIE + VEGGIE correctly.
 */
export function missingCount(recipe: RecipeDef, plate: CardInstance[]): number {
  const reqs = recipe.requires;
  const used = new Array<boolean>(plate.length).fill(false);
  let best = reqs.length;

  const search = (i: number, missing: number): void => {
    if (missing >= best) return;
    if (i === reqs.length) {
      best = missing;
      return;
    }
    for (let p = 0; p < plate.length; p++) {
      if (!used[p] && fits(reqs[i], plate[p])) {
        used[p] = true;
        search(i + 1, missing);
        used[p] = false;
        if (best === 0) return;
      }
    }
    search(i + 1, missing + 1);
  };
  search(0, 0);
  return best;
}

export interface RecipeCheck {
  /** Fully satisfied: can be served now. */
  ready: RecipeDef[];
  /** Exactly one requirement short (GDD §4.3 real-time hint). */
  almost: RecipeDef[];
}

export function checkRecipes(known: RecipeDef[], plate: CardInstance[]): RecipeCheck {
  const ready: RecipeDef[] = [];
  const almost: RecipeDef[] = [];
  for (const r of known) {
    const m = missingCount(r, plate);
    if (m === 0) ready.push(r);
    else if (m === 1) almost.push(r);
  }
  return { ready, almost };
}

export function plateQuality(plate: CardInstance[]): number {
  return plate.reduce((sum, c) => sum + (c.def.quality ?? 0), 0);
}

/**
 * Perfect Order: the recipe's ingredients sit on the Prep Board in the same order the
 * Recipe Book lists them (other ingredients may sit in between). Greedy subsequence
 * matching is optimal here: taking the earliest fitting ingredient never hurts later slots.
 */
export function inOrder(recipe: RecipeDef, plate: CardInstance[]): boolean {
  let r = 0;
  for (const c of plate) {
    if (r < recipe.requires.length && fits(recipe.requires[r], c)) r++;
  }
  return r === recipe.requires.length;
}

export interface Dish {
  recipe: RecipeDef;
  inOrder: boolean;
}

/**
 * The dish the board cooks into. The Recipe Book is closed during a duel, so the game
 * picks for the player: a Perfect Order match first, then the recipe with more slots.
 */
export function bestDish(known: RecipeDef[], plate: CardInstance[]): Dish | null {
  const dishes = known
    .filter((r) => missingCount(r, plate) === 0)
    .map((recipe) => ({ recipe, inOrder: inOrder(recipe, plate) }));
  const power = (r: RecipeDef) => r.effects.reduce((s, e) => s + e.amount, 0);
  dishes.sort(
    (a, b) =>
      Number(b.inOrder) - Number(a.inOrder) ||
      b.recipe.requires.length - a.recipe.requires.length ||
      power(b.recipe) - power(a.recipe),
  );
  return dishes[0] ?? null;
}
