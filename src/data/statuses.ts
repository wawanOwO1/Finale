import type { StatusId } from '../core/types.ts';

export interface StatusDef {
  id: StatusId;
  name: string;
  /** Icon sprite id (ui/icons.ts). */
  icon: string;
  debuff: boolean;
  /** Tooltip text; X = stacks. */
  text: string;
}

/** GDD §4.7. Every status has a tooltip. */
export const STATUSES: Record<StatusId, StatusDef> = {
  spicy: {
    id: 'spicy', name: 'Spicy', icon: 'spicy', debuff: true,
    text: 'Loses X Confidence at the start of its turn, ignoring Composure. Then X goes down by 1.',
  },
  flustered: {
    id: 'flustered', name: 'Flustered', icon: 'flustered', debuff: true,
    text: 'Deals 25% less Pressure. Lasts X turns.',
  },
  rattled: {
    id: 'rattled', name: 'Rattled', icon: 'rattled', debuff: true,
    text: 'Takes 50% more Pressure. Lasts X turns.',
  },
  burnt: {
    id: 'burnt', name: 'Burnt', icon: 'burnt', debuff: true,
    text: 'The next X Serves have 50% less effect.',
  },
  focus: {
    id: 'focus', name: 'Focus', icon: 'focus', debuff: false,
    text: 'Adds X Pressure to every attack. Lasts the whole duel.',
  },
  inspired: {
    id: 'inspired', name: 'Inspired', icon: 'inspired', debuff: false,
    text: 'Draw X more cards next turn.',
  },
};

/** Order Fresh Salad's cleanse removes debuffs in: the most harmful first. */
export const CLEANSE_ORDER: StatusId[] = ['burnt', 'spicy', 'rattled', 'flustered'];
