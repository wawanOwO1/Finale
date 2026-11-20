import * as THREE from 'three';
import './style.css';
import { Duel } from './core/duel';
import { CARDS, DEV_DECK, STARTER_DECK } from './data/cards';
import { ENEMIES } from './data/enemies';
import { BOOKS, RECIPES } from './data/recipes';
import { GameRenderer } from './render3d/renderer';
import { createStage } from './render3d/stage';
import { createHud } from './ui/hud';

const canvas = document.querySelector<HTMLCanvasElement>('#scene')!;
const uiRoot = document.querySelector<HTMLElement>('#ui')!;

const gfx = new GameRenderer(canvas);
const stage = createStage(gfx.camera);
const hud = createHud(uiRoot);

hud.onTogglePixel(() => {
  gfx.setPixelated(!gfx.isPixelated);
  hud.setPixelLabel(gfx.isPixelated);
});

/**
 * Graybox: one duel, Tony + starter deck + Basics Cookbook by default.
 * Dev URL params until the Course Path exists:
 *   ?enemy=rosa   pick the rival
 *   ?deck=dev     starter + status cards, all four Recipe Books
 *   ?hype=100     start with Hype (100 = Signature Dish in hand)
 */
const params = new URLSearchParams(location.search);
const dev = params.get('deck') === 'dev';
const enemy = ENEMIES[params.get('enemy') ?? ''] ?? ENEMIES.tony;
const recipes = (dev ? Object.keys(BOOKS) : ['basics']).flatMap((b) => BOOKS[b].recipes.map((id) => RECIPES[id]));

async function startDuel(): Promise<void> {
  stage.setPlate([]);
  // The Recipe Book is only readable before the duel: memorize the orders.
  await hud.showCookbook(recipes);
  const duel = new Duel({
    deck: (dev ? DEV_DECK : STARTER_DECK).map((id) => CARDS[id]),
    enemy,
    recipes,
    hype: Number(params.get('hype')) || 0,
  });
  // Visuals listen to the event bus; the duel never knows about them (GDD §9).
  duel.bus.on('changed', () => stage.setPlate(duel.plate.map((c) => c.def.tags?.[0] ?? '')));
  duel.bus.on('confidence_lost', (e) => stage.hit(e.target === 'enemy' ? 'rival' : 'player'));
  hud.bind(duel, enemy.name);
}

startDuel();
hud.onRestart(() => startDuel());

// Project a 3D point to screen pixels (for UI that follows 3D objects).
const tmp = new THREE.Vector3();
function toScreen(obj: THREE.Object3D): { x: number; y: number } {
  obj.getWorldPosition(tmp).project(gfx.camera);
  return {
    x: (tmp.x * 0.5 + 0.5) * window.innerWidth,
    y: (-tmp.y * 0.5 + 0.5) * window.innerHeight,
  };
}

const clock = new THREE.Clock();
function frame(): void {
  const t = clock.getElapsedTime();
  stage.update(t);
  hud.setAnchors({
    rival: toScreen(stage.rivalIntentAnchor),
    player: toScreen(stage.playerAnchor),
    board: toScreen(stage.boardAnchor),
  });
  gfx.render(stage.scene);
  requestAnimationFrame(frame);
}
frame();
