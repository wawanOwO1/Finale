import type { CardDef } from '../core/types';
import { STATUSES } from '../data/statuses';

/**
 * Keyword tooltips (GDD §7.3 "tooltip keyword di mana-mana"). Card text highlights
 * these words, and hovering a card lists what each one means, Slay-the-Spire style.
 */
export interface Keyword {
  name: string;
  icon: string;
  text: string;
}

export const KEYWORDS: Record<string, Keyword> = {
  Pressure: { name: 'Pressure', icon: 'pressure', text: "Hits the rival's Composure first, then their Confidence." },
  Composure: { name: 'Composure', icon: 'composure', text: 'Blocks incoming Pressure. Fades at the start of your turn.' },
  Confidence: { name: 'Confidence', icon: 'confidence', text: 'A chef at 0 Confidence gives up.' },
  Quality: {
    name: 'Quality', icon: 'hype',
    text: "When you Serve a recipe, the board's total Quality is added to its main effect.",
  },
  Hype: { name: 'Hype', icon: 'hype', text: 'The crowd meter. At 100, your Signature Dish appears in hand.' },
  Heat: { name: 'Heat', icon: 'heat', text: 'Spent to play cards and to Serve. Refills to 3 each turn.' },
  Draw: { name: 'Draw', icon: 'draw', text: 'Take cards from your draw pile.' },
  Retain: { name: 'Retain', icon: 'check', text: 'Stays in your hand at the end of the turn.' },
  Serve: {
    name: 'Serve', icon: 'serve',
    text: 'Cook everything on the Prep Board. Ingredients in Recipe Book order give a Perfect Order (x1.5).',
  },
  ...Object.fromEntries(
    Object.values(STATUSES).map((s) => [s.name, { name: s.name, icon: s.icon, text: s.text }]),
  ),
};

const KEYWORD_RE = new RegExp(`\\b(${Object.keys(KEYWORDS).join('|')})\\b`, 'g');

const esc = (s: string) => s.replace(/[&<>"]/g, (c) => `&#${c.charCodeAt(0)};`);

/** Card text as HTML with keywords highlighted. */
export function highlight(text: string): string {
  return esc(text).replace(KEYWORD_RE, '<span class="kw">$1</span>');
}

/** Keywords that explain a card, in reading order, without duplicates. */
export function cardKeywords(def: CardDef): Keyword[] {
  const names = new Set<string>();
  for (const m of def.text.matchAll(KEYWORD_RE)) names.add(m[1]);
  if (def.type === 'ingredient') names.add('Quality');
  return [...names].map((n) => KEYWORDS[n]);
}

/** The first tooltip line: what this kind of card does when you drag it. */
export function cardRole(def: CardDef): Keyword {
  if (def.special === 'signature') {
    return { name: 'Signature Dish', icon: 'crown', text: 'Drag up to play. Your next Serve has x2 effect.' };
  }
  if (def.type === 'ingredient') {
    return {
      name: 'Ingredient', icon: def.tags?.[0] ?? 'PROTEIN',
      text: 'Drag onto the Prep Board. Order matters: match your Recipe Book.',
    };
  }
  return { name: 'Technique', icon: 'technique', text: 'Drag up out of your hand to play it.' };
}
