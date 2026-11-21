/**
 * One-shot migration helper: writes the TypeScript content (src/data/*) as Godot .tres
 * resources into godot/data/. After the migration the .tres files are the source of truth
 * (edit them in the Godot Inspector); rerunning this OVERWRITES them.
 * Run: node scripts/export-godot-data.ts
 */
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { CardDef, Effect, EnemyDef, Intent, RecipeDef, Requirement } from '../src/core/types.ts';
import { CARDS, DEV_DECK, STARTER_DECK } from '../src/data/cards.ts';
import { ENEMIES } from '../src/data/enemies.ts';
import { BOOKS, RECIPES } from '../src/data/recipes.ts';

const OUT = join(import.meta.dirname, '..', 'godot', 'data');
const SCRIPTS = 'res://scripts/data';

const KIND = ['pressure', 'composure', 'heal', 'draw', 'hype', 'status', 'cleanse'];
const str = (s: string) => JSON.stringify(s);
const strArr = (items: string[]) => `Array[String]([${items.map(str).join(', ')}])`;

/** Builds one .tres file: ext scripts/resources, sub-resources, then [resource]. */
class Tres {
  private ext: string[] = [];
  private extIds = new Map<string, string>();
  private subs: string[] = [];

  private scriptClass: string;
  constructor(scriptClass: string) {
    this.scriptClass = scriptClass;
  }

  extRes(type: string, path: string): string {
    const key = `${type}|${path}`;
    let id = this.extIds.get(key);
    if (!id) {
      id = String(this.extIds.size + 1);
      this.extIds.set(key, id);
      this.ext.push(`[ext_resource type="${type}" path="${path}" id="${id}"]`);
    }
    return `ExtResource("${id}")`;
  }

  sub(lines: string[]): string {
    const id = `sub_${this.subs.length + 1}`;
    this.subs.push(`[sub_resource type="Resource" id="${id}"]\n${lines.join('\n')}`);
    return `SubResource("${id}")`;
  }

  effects(list: Effect[]): string {
    const script = this.extRes('Script', `${SCRIPTS}/effect_def.gd`);
    const items = list.map((e) => {
      const lines = [`script = ${script}`, `kind = ${KIND.indexOf(e.kind)}`, `amount = ${e.amount}`];
      if (e.kind === 'status') {
        lines.push(`status = ${str(e.status)}`, `target = ${e.target === 'self' ? 1 : 0}`);
      }
      return this.sub(lines);
    });
    return `Array[${script}]([${items.join(', ')}])`;
  }

  build(body: string[]): string {
    const script = this.extRes('Script', `${SCRIPTS}/${snake(this.scriptClass)}.gd`);
    return [
      `[gd_resource type="Resource" script_class="${this.scriptClass}" format=3]`,
      '',
      ...this.ext,
      '',
      ...this.subs.flatMap((s) => [s, '']),
      '[resource]',
      `script = ${script}`,
      ...body,
      '',
    ].join('\n');
  }
}

const snake = (cls: string) => cls.replace(/([a-z])([A-Z])/g, '$1_$2').toLowerCase();

function write(dir: string, id: string, text: string): void {
  mkdirSync(join(OUT, dir), { recursive: true });
  writeFileSync(join(OUT, dir, `${id}.tres`), text);
}

function card(c: CardDef): string {
  const t = new Tres('CardDef');
  const body = [
    `id = ${str(c.id)}`,
    `name = ${str(c.name)}`,
    `type = ${c.type === 'ingredient' ? 0 : 1}`,
    `cost = ${c.cost}`,
  ];
  if (c.tags) body.push(`tags = ${strArr(c.tags)}`);
  if (c.quality) body.push(`quality = ${c.quality}`);
  if (c.effects.length) body.push(`effects = ${t.effects(c.effects)}`);
  body.push(`text = ${str(c.text)}`);
  if (c.retain) body.push('retain = true');
  if (c.exhaust) body.push('exhaust = true');
  if (c.special) body.push(`special = ${str(c.special)}`);
  return t.build(body);
}

const req = (r: Requirement) => ('card' in r ? `card:${r.card}` : r.tag);

function recipe(r: RecipeDef): string {
  const t = new Tres('RecipeDef');
  return t.build([
    `id = ${str(r.id)}`,
    `name = ${str(r.name)}`,
    `book = ${str(r.book)}`,
    `requires = PackedStringArray(${r.requires.map((x) => str(req(x))).join(', ')})`,
    `effects = ${t.effects(r.effects)}`,
    `hype = ${r.hype}`,
    `text = ${str(r.text)}`,
  ]);
}

function intent(t: Tres, i: Intent): string {
  const lines = [`script = ${t.extRes('Script', `${SCRIPTS}/intent_def.gd`)}`, `label = ${str(i.label)}`];
  if (i.attack !== undefined) lines.push(`attack = ${i.attack}`);
  if (i.block) lines.push(`block = ${i.block}`);
  if (i.status) {
    lines.push(
      `status = ${str(i.status.id)}`,
      `status_amount = ${i.status.amount}`,
      `status_target = ${i.status.target === 'player' ? 0 : 1}`,
    );
  }
  return t.sub(lines);
}

function enemy(e: EnemyDef): string {
  const t = new Tres('EnemyDef');
  const script = t.extRes('Script', `${SCRIPTS}/intent_def.gd`);
  const pattern = e.pattern.map((i) => intent(t, i));
  return t.build([
    `id = ${str(e.id)}`,
    `name = ${str(e.name)}`,
    `title = ${str(e.title)}`,
    `confidence = ${e.confidence}`,
    `pattern = Array[${script}]([${pattern.join(', ')}])`,
  ]);
}

/** A typed array of other .tres files (books → recipes, decks → cards). */
function refs(t: Tres, cls: string, dir: string, ids: string[]): string {
  const script = t.extRes('Script', `${SCRIPTS}/${snake(cls)}.gd`);
  const items = ids.map((id) => t.extRes('Resource', `res://data/${dir}/${id}.tres`));
  return `Array[${script}]([${items.join(', ')}])`;
}

function book(id: string, b: { name: string; recipes: string[] }): string {
  const t = new Tres('BookDef');
  const list = refs(t, 'RecipeDef', 'recipes', b.recipes);
  return t.build([`id = ${str(id)}`, `name = ${str(b.name)}`, `recipes = ${list}`]);
}

function deck(id: string, cards: string[]): string {
  const t = new Tres('DeckDef');
  const list = refs(t, 'CardDef', 'cards', cards);
  return t.build([`id = ${str(id)}`, `cards = ${list}`]);
}

for (const c of Object.values(CARDS)) write('cards', c.id, card(c));
for (const r of Object.values(RECIPES)) write('recipes', r.id, recipe(r));
for (const e of Object.values(ENEMIES)) write('enemies', e.id, enemy(e));
for (const [id, b] of Object.entries(BOOKS)) write('books', id, book(id, b));
write('decks', 'starter', deck('starter', STARTER_DECK));
write('decks', 'dev', deck('dev', DEV_DECK));

console.log(
  `Wrote ${Object.keys(CARDS).length} cards, ${Object.keys(RECIPES).length} recipes, ` +
    `${Object.keys(ENEMIES).length} enemies, ${Object.keys(BOOKS).length} books, 2 decks → ${OUT}`,
);
