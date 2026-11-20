/**
 * Headless duel checks + random playthroughs. No 3D, no DOM.
 * Run: npm run sim   (Node ≥ 22.18 strips the TypeScript types natively)
 */
import { Duel } from '../src/core/duel.ts';
import { bestDish, inOrder, missingCount } from '../src/core/recipes.ts';
import type { CardInstance, EnemyDef } from '../src/core/types.ts';
import { CARDS, DEV_DECK, STARTER_DECK } from '../src/data/cards.ts';
import { ENEMIES } from '../src/data/enemies.ts';
import { BOOKS, RECIPES } from '../src/data/recipes.ts';

let failures = 0;
function check(name: string, cond: boolean, detail = ''): void {
  if (!cond) failures++;
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${!cond && detail ? `  (${detail})` : ''}`);
}

let uidSeq = 10_000;
const inst = (...ids: string[]): CardInstance[] => ids.map((id) => ({ uid: uidSeq++, def: CARDS[id] }));
const allRecipes = Object.values(RECIPES);
const basics = BOOKS.basics.recipes.map((id) => RECIPES[id]);

/** A rival that only blocks 0, so tests control exactly what happens. */
const dummy: EnemyDef = { id: 'dummy', name: 'Dummy', title: 'test', confidence: 200, pattern: [{ label: 'Idle' }] };

function newDuel(seed: number, opts: Partial<{ enemy: EnemyDef; hype: number; all: boolean }> = {}): Duel {
  return new Duel({
    deck: STARTER_DECK.map((id) => CARDS[id]),
    enemy: opts.enemy ?? ENEMIES.tony,
    recipes: opts.all ? allRecipes : basics,
    hype: opts.hype,
    seed,
  });
}
/** Put exact cards in hand (and nothing else). */
function giveHand(d: Duel, ...ids: string[]): CardInstance[] {
  d.hand = inst(...ids);
  return d.hand;
}
const lost = (d: Duel, before: number) => before - d.enemy.confidence;

// ---------------------------------------------------------------- recipe matching
check('omelette matches egg+butter+tomato', missingCount(RECIPES.omelette, inst('egg', 'butter', 'tomato')) === 0);
check('omelette with extras still matches', missingCount(RECIPES.omelette, inst('egg', 'butter', 'tomato', 'bread')) === 0);
check('omelette missing VEGGIE is 1 short', missingCount(RECIPES.omelette, inst('egg', 'butter')) === 1);
check('salad needs two distinct VEGGIE', missingCount(RECIPES.freshSalad, inst('tomato')) === 1);
check('toast matches bread+butter', missingCount(RECIPES.toast, inst('bread', 'butter')) === 0);
check('steak needs Beef, not any PROTEIN', missingCount(RECIPES.classicSteak, inst('chicken', 'butter', 'chili')) === 1);
check('steak with Beef matches', missingCount(RECIPES.classicSteak, inst('beef', 'butter', 'chili')) === 0);

// ---------------------------------------------------------------- core loop
{
  const d = newDuel(1);
  check('starts with 5 cards, 3 Heat, turn 1', d.hand.length === 5 && d.player.heat === 3 && d.turn === 1);
}
{
  const d = newDuel(2);
  d.hand = [];
  d.plate = inst('butter', 'bread'); // out of order (book: CARB -> FAT)
  const before = d.enemy.confidence;
  check('toast serve ok', d.serve('toast').ok);
  check('toast out of order deals 6 + 2 Quality', lost(d, before) === 8);
  check('serve costs 1 Heat, Hype +25', d.player.heat === 2 && d.hype === 25);
  check('cannot serve twice per turn', !d.serve(null).ok);
  check('toast draws 1', d.hand.length === 1);
}
{
  const d = newDuel(3);
  d.plate = inst('egg', 'egg', 'bread');
  const before = d.enemy.confidence;
  d.serve(null);
  check('improvised deals 2 × 3', lost(d, before) === 6);
  check('serving a non-matching recipe is refused', !newDuel(3).serve('omelette').ok);
}
{
  const d = newDuel(4);
  d.plate = inst('egg');
  d.player.composure = 4;
  const conf = d.player.confidence;
  d.endTurn(); // Tony: Prepping 6
  check('plate kept across turns', d.plate.length === 1);
  check('composure absorbs 4 of 6', conf - d.player.confidence === 2);
  check('composure reset on new turn', d.player.composure === 0 && d.turn === 2);
}

// ---------------------------------------------------------------- Perfect Order (book order on the board)
check('omelette in book order (FAT, PROTEIN, VEGGIE)', inOrder(RECIPES.omelette, inst('butter', 'egg', 'tomato')));
check('omelette out of order', !inOrder(RECIPES.omelette, inst('egg', 'butter', 'tomato')));
check('extras between still count as in order', inOrder(RECIPES.omelette, inst('butter', 'bread', 'egg', 'tomato')));
check('bestDish prefers the in-order recipe',
  bestDish(basics, inst('bread', 'butter', 'tomato', 'egg'))?.recipe.id === 'toast');
check('bestDish prefers the bigger recipe when both in order',
  bestDish(basics, inst('butter', 'egg', 'tomato', 'bread'))?.recipe.id === 'omelette');
{
  const d = newDuel(20, { enemy: dummy });
  d.plate = inst('bread', 'butter');
  const before = d.enemy.confidence;
  let perfect = false;
  d.bus.on('dish_revealed', (e) => (perfect = e.perfect));
  d.serve();
  check('Perfect Order Toast: (6 + 2) x1.5 = 12', lost(d, before) === 12 && perfect);
}
{
  const d = newDuel(21, { enemy: dummy });
  d.plate = inst('egg', 'egg');
  let name = '';
  d.bus.on('dish_revealed', (e) => (name = e.recipe?.name ?? 'Improvised'));
  d.serve();
  check('auto Serve with no recipe is Improvised', name === 'Improvised');
}

// ---------------------------------------------------------------- statuses
{
  const d = newDuel(5, { enemy: dummy });
  const [stare, chop] = giveHand(d, 'stareDown', 'quickChop');
  d.play(stare.uid);
  check('Stare Down: rival Rattled 2', d.enemy.statuses.rattled === 2);
  const before = d.enemy.confidence;
  d.play(chop.uid);
  check('Rattled: 6 Pressure becomes 9', lost(d, before) === 9);
  d.endTurn();
  check('Rattled counts down at the end of the rival turn', d.enemy.statuses.rattled === 1);
  d.endTurn();
  check('Rattled expires after 2 rival turns', d.enemy.statuses.rattled === undefined);
}
{
  const d = newDuel(6, { enemy: ENEMIES.rosa });
  const conf = d.player.confidence;
  check('intent preview matches Rosa taunt (4)', d.pressureFrom('enemy', d.intent.attack!) === 4);
  d.endTurn(); // Rosa: Taunt (4 Pressure, Flustered 2)
  check('Rosa taunt: 4 Pressure + Flustered 2', conf - d.player.confidence === 4 && d.player.statuses.flustered === 2);
  const [chop] = giveHand(d, 'quickChop');
  const before = d.enemy.confidence;
  d.play(chop.uid);
  check('Flustered: 6 Pressure becomes 4', lost(d, before) === 4);
  d.endTurn();
  check('player Flustered counts down at end of own turn', d.player.statuses.flustered === 1);
}
{
  const d = newDuel(7, { enemy: dummy });
  const [chili] = giveHand(d, 'chili');
  d.play(chili.uid);
  check('Chili: rival Spicy 2', d.enemy.statuses.spicy === 2);
  const before = d.enemy.confidence;
  d.enemy.composure = 50; // Spicy ignores Composure
  d.endTurn();
  check('Spicy ticks 2 at rival turn start, ignores Composure', lost(d, before) === 2);
  check('Spicy then drops to 1', d.enemy.statuses.spicy === 1);
}
{
  const d = newDuel(8, { enemy: dummy, all: true });
  d.plate = inst('egg', 'chili');
  d.serve('skewers');
  check('Skewers gives Focus 1', d.player.statuses.focus === 1);
  const [chop] = giveHand(d, 'quickChop');
  const before = d.enemy.confidence;
  d.play(chop.uid);
  check('Focus: 6 Pressure becomes 7', lost(d, before) === 7);
}
{
  const d = newDuel(9, { enemy: dummy });
  d.player.statuses.burnt = 1;
  d.plate = inst('butter', 'bread');
  const before = d.enemy.confidence;
  d.serve('toast');
  check('Burnt halves the Serve: (6+2) / 2 = 4', lost(d, before) === 4);
  check('Burnt is used up', d.player.statuses.burnt === undefined);
}
{
  const d = newDuel(10, { enemy: dummy, all: true });
  d.plate = inst('bread', 'tomato', 'cheese');
  d.serve('mushroomRisotto');
  check('Risotto gives Inspired 1', d.player.statuses.inspired === 1);
  d.endTurn();
  check('Inspired: draw 6 next turn, then gone', d.hand.length === 6 && d.player.statuses.inspired === undefined);
}
{
  const d = newDuel(11, { enemy: dummy });
  d.player.statuses.spicy = 3;
  d.player.statuses.flustered = 2;
  d.plate = inst('tomato', 'tomato');
  d.serve('freshSalad');
  check('Fresh Salad removes 1 debuff (Spicy before Flustered)', d.player.statuses.spicy === undefined && d.player.statuses.flustered === 2);
}

// ---------------------------------------------------------------- Signature Dish
{
  const d = newDuel(12, { enemy: dummy });
  check('no Signature card below 100 Hype', !d.hand.some((c) => c.def.special === 'signature'));
  d.plate = inst('butter', 'bread');
  d.hype = 75;
  d.serve('toast');
  const sig = d.hand.find((c) => c.def.special === 'signature');
  check('Hype 100 puts Signature Dish in hand', d.hype === 100 && !!sig);
  d.endTurn();
  check('Signature Dish is retained over End Turn', d.hand.some((c) => c.def.special === 'signature'));

  let cutIn = '';
  d.bus.on('signature_served', (e) => (cutIn = e.dish));
  d.play(d.hand.find((c) => c.def.special === 'signature')!.uid);
  check('playing it arms the next Serve', d.signatureArmed && d.exhausted.length === 1);
  d.plate = inst('butter', 'bread');
  const before = d.enemy.confidence;
  d.serve('toast');
  check('Signature Serve: (6+2) × 2 = 16', lost(d, before) === 16);
  check('cut-in event fires with the dish name', cutIn === 'Toast');
  check('Hype spent, not re-armed', d.hype === 0 && !d.signatureArmed);
  d.endTurn();
  d.plate = inst('bread', 'butter');
  d.hype = 99;
  d.serve('toast');
  check('only once per duel', d.hype === 100 && !d.hand.some((c) => c.def.special === 'signature'));
}
{
  const d = newDuel(13, { enemy: dummy, hype: 100 });
  check('?hype=100 start hands out the Signature Dish', d.hand.some((c) => c.def.special === 'signature'));
}

// ---------------------------------------------------------------- random playthroughs
function playthroughs(label: string, deck: string[], enemy: EnemyDef, recipes = basics): void {
  let wins = 0;
  let turnsTotal = 0;
  let conserved = true;
  let signatures = 0;
  const N = 500;
  for (let seed = 1; seed <= N; seed++) {
    const d = new Duel({ deck: deck.map((id) => CARDS[id]), enemy, recipes, seed });
    d.bus.on('signature_served', () => signatures++);
    let rnd = seed * 7919;
    const pick = (n: number) => (rnd = (rnd * 1103515245 + 12345) % 2147483648) % n;
    let safety = 0;
    while (d.phase === 'player' && safety++ < 100) {
      for (let k = 0; k < 10; k++) {
        const playable = d.hand.filter((c) => d.canPlay(c.uid).ok);
        if (playable.length === 0) break;
        d.play(playable[pick(playable.length)].uid);
      }
      const ready = d.recipeCheck.ready;
      if (d.canServe().ok && (ready.length > 0 || d.plate.length >= 4)) d.serve();
      const total = d.drawPile.length + d.hand.length + d.discard.length + d.plate.length + d.exhausted.length;
      if (total !== deck.length + (d.signatureGiven ? 1 : 0)) conserved = false;
      if (d.phase === 'player') d.endTurn();
    }
    if (d.phase === 'won') wins++;
    turnsTotal += d.turn;
  }
  check(`${label}: cards conserved, every duel ends`, conserved);
  console.log(`      random bot: ${wins}/${N} wins, avg ${(turnsTotal / N).toFixed(1)} turns, ${signatures} Signature Dishes`);
}
playthroughs('starter vs Tony', STARTER_DECK, ENEMIES.tony);
playthroughs('starter vs Rosa', STARTER_DECK, ENEMIES.rosa);
playthroughs('dev deck vs Rosa', DEV_DECK, ENEMIES.rosa, allRecipes);

console.log(failures ? `\n${failures} check(s) failed` : '\nAll checks passed');
if (failures) throw new Error('sim failed');
