/**
 * Headless duel checks + random playthroughs. No 3D, no DOM.
 * Run: npm run sim   (Node ≥ 22.18 strips the TypeScript types natively)
 */
import { Duel } from '../src/core/duel.ts';
import { missingCount } from '../src/core/recipes.ts';
import type { CardInstance } from '../src/core/types.ts';
import { CARDS, STARTER_DECK } from '../src/data/cards.ts';
import { ENEMIES } from '../src/data/enemies.ts';
import { BOOKS, RECIPES } from '../src/data/recipes.ts';

let failures = 0;
function check(name: string, cond: boolean): void {
  if (!cond) failures++;
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}`);
}

const inst = (...ids: string[]): CardInstance[] => ids.map((id, uid) => ({ uid, def: CARDS[id] }));
const basics = BOOKS.basics.recipes.map((id) => RECIPES[id]);
const newDuel = (seed: number) =>
  new Duel({ deck: STARTER_DECK.map((id) => CARDS[id]), enemy: ENEMIES.tony, recipes: basics, seed });

// ---- recipe matching
check('omelette matches egg+butter+tomato', missingCount(RECIPES.omelette, inst('egg', 'butter', 'tomato')) === 0);
check('omelette with extras still matches', missingCount(RECIPES.omelette, inst('egg', 'butter', 'tomato', 'bread')) === 0);
check('omelette missing VEGGIE is 1 short', missingCount(RECIPES.omelette, inst('egg', 'butter')) === 1);
check('salad needs two distinct VEGGIE', missingCount(RECIPES.freshSalad, inst('tomato')) === 1);
check('toast matches bread+butter', missingCount(RECIPES.toast, inst('bread', 'butter')) === 0);

// ---- turn start
{
  const d = newDuel(1);
  check('starts with 5 cards, 3 Heat, turn 1', d.hand.length === 5 && d.player.heat === 3 && d.turn === 1);
}

// ---- serve a recipe: Toast = 6 + Quality 2 = 8 Pressure
{
  const d = newDuel(2);
  d.hand = [];
  d.plate = inst('bread', 'butter').map((c, i) => ({ ...c, uid: 100 + i }));
  const before = d.enemy.confidence;
  const r = d.serve('toast');
  check('toast serve ok', r.ok);
  check('toast deals 6 + 2 Quality', before - d.enemy.confidence === 8);
  check('serve costs 1 Heat, Hype +25', d.player.heat === 2 && d.hype === 25);
  check('cannot serve twice per turn', !d.serve(null).ok);
  check('toast draws 1', d.hand.length === 1);
}

// ---- improvised dish: 2 × ingredient count
{
  const d = newDuel(3);
  d.plate = inst('egg', 'egg', 'bread').map((c, i) => ({ ...c, uid: 200 + i }));
  const before = d.enemy.confidence;
  d.serve(null);
  check('improvised deals 2 × 3', before - d.enemy.confidence === 6);
  check('serving a non-matching recipe is refused', !newDuel(3).serve('omelette').ok);
}

// ---- plate persists, composure blocks enemy pressure
{
  const d = newDuel(4);
  d.plate = inst('egg').map((c) => ({ ...c, uid: 300 }));
  d.player.composure = 4;
  const conf = d.player.confidence;
  d.endTurn(); // Tony: Prepping 6
  check('plate kept across turns', d.plate.length === 1);
  check('composure absorbs 4 of 6', conf - d.player.confidence === 2);
  check('composure reset on new turn', d.player.composure === 0 && d.turn === 2);
}

// ---- random playthroughs: every duel must end, no card may vanish
{
  let wins = 0;
  let turnsTotal = 0;
  const N = 500;
  let conserved = true;
  for (let seed = 1; seed <= N; seed++) {
    const d = newDuel(seed);
    let rnd = seed * 7919;
    const pick = (n: number) => (rnd = (rnd * 1103515245 + 12345) % 2147483648) % n;
    let safety = 0;
    while (d.phase === 'player' && safety++ < 100) {
      // Greedy-ish: play what we can, serve a ready recipe if any, else maybe improvise.
      for (let k = 0; k < 8; k++) {
        const playable = d.hand.filter((c) => d.canPlay(c.uid).ok);
        if (playable.length === 0) break;
        d.play(playable[pick(playable.length)].uid);
      }
      const ready = d.recipeCheck.ready;
      if (d.canServe().ok && (ready.length > 0 || d.plate.length >= 4)) d.serve(ready[0]?.id ?? null);
      const total = d.drawPile.length + d.hand.length + d.discard.length + d.plate.length;
      if (total !== STARTER_DECK.length) conserved = false;
      if (d.phase === 'player') d.endTurn();
    }
    if (d.phase === 'won') wins++;
    turnsTotal += d.turn;
  }
  check('all cards conserved in every duel', conserved);
  console.log(`      random bot vs Tony: ${wins}/${N} wins, avg ${(turnsTotal / N).toFixed(1)} turns`);
  check('random bot beats Tony sometimes', wins > 0);
}

console.log(failures ? `\n${failures} check(s) failed` : '\nAll checks passed');
if (failures) throw new Error('sim failed');
