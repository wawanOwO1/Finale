import * as THREE from 'three';
import './style.css';
import { Duel } from './core/duel';
import { CARDS, STARTER_DECK } from './data/cards';
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

/** Graybox milestone: one duel against Tony with the starter deck + Basics Cookbook. */
function startDuel(): Duel {
  const duel = new Duel({
    deck: STARTER_DECK.map((id) => CARDS[id]),
    enemy: ENEMIES.tony,
    recipes: BOOKS.basics.recipes.map((id) => RECIPES[id]),
  });
  // Visuals listen to the event bus; the duel never knows about them (GDD §9).
  duel.bus.on('changed', () => stage.setPlate(duel.plate.map((c) => c.def.tags?.[0] ?? '')));
  duel.bus.on('pressure_dealt', (e) => {
    if (e.amount > e.blocked) stage.hit(e.target === 'enemy' ? 'rival' : 'player');
  });
  stage.setPlate([]);
  hud.bind(duel);
  return duel;
}

startDuel();
hud.onRestart(() => startDuel());

// Project a 3D point to screen pixels (for labels that follow 3D objects).
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
  const p = toScreen(stage.rivalIntentAnchor);
  hud.setIntentPosition(p.x, p.y);
  const q = toScreen(stage.plateAnchor);
  hud.setPlatePosition(q.x, q.y);
  gfx.render(stage.scene);
  requestAnimationFrame(frame);
}
frame();
