import * as THREE from 'three';
import './style.css';
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
  gfx.render(stage.scene);
  requestAnimationFrame(frame);
}
frame();
