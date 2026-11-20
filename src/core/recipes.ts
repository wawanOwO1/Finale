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

/** Human-readable requirement, e.g. "VEGGIE" or "Beef". */
export function requirementLabel(req: Requirement): string {
  return 'card' in req ? req.card : req.tag;
}
