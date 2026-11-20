import type { CardInstance, Intent, RecipeDef, StatusId } from './types.ts';

/** Events the duel emits; visuals and audio listen, logic never depends on them (GDD §9). */
export interface DuelEvents {
  turn_started: { turn: number };
  card_played: { card: CardInstance };
  dish_served: { recipe: RecipeDef | null; pressure: number; quality: number; count: number };
  pressure_dealt: { target: 'player' | 'enemy'; amount: number; blocked: number };
  confidence_lost: { target: 'player' | 'enemy'; amount: number; source: 'pressure' | 'spicy' };
  composure_gained:{ target: 'player' | 'enemy'; amount: number };
  enemy_acted: { intent: Intent };
  status_applied: { target: 'player' | 'enemy'; status: StatusId; amount: number };
  signature_ready: Record<string, never>;
  signature_served: { dish: string };
  dish_revealed: { recipe: RecipeDef | null; perfect: boolean; signature: boolean; burnt: boolean };
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
