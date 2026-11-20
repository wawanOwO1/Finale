import type { CardInstance, Intent, RecipeDef } from './types.ts';

/** Events the duel emits; visuals and audio listen, logic never depends on them (GDD §9). */
export interface DuelEvents {
  turn_started: { turn: number };
  card_played: { card: CardInstance };
  dish_served: { recipe: RecipeDef | null; pressure: number; quality: number; count: number };
  pressure_dealt: { target: 'player' | 'enemy'; amount: number; blocked: number };
  composure_gained: { target: 'player' | 'enemy'; amount: number };
  enemy_acted: { intent: Intent };
  duel_ended: { winner: 'player' | 'enemy' };
  changed: Record<string, never>;
}

type Handler<T> = (payload: T) => void;

export class EventBus<E> {
  private handlers: { [K in keyof E]?: Handler<E[K]>[] } = {};

  on<K extends keyof E>(type: K, handler: Handler<E[K]>): () => void {
    const list = (this.handlers[type] ??= []);
    list.push(handler);
    return () => {
      const i = list.indexOf(handler);
      if (i >= 0) list.splice(i, 1);
    };
  }

  emit<K extends keyof E>(type: K, payload: E[K]): void {
    for (const h of this.handlers[type] ?? []) h(payload);
  }
}
