import * as THREE from 'three';
import { PALETTE } from './palette';

/** Flat-shaded material: one solid color per face, no textures (GDD §7.1). */
const flat = (color: number) => new THREE.MeshLambertMaterial({ color, flatShading: true });

function box(w: number, h: number, d: number, color: number): THREE.Mesh {
  const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), flat(color));
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

/** Placeholder chef: capsule body + oversized head (stylized proportions, GDD §7.1). */
function makeChef(bodyColor: number): THREE.Group {
  const chef = new THREE.Group();

  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.45, 0.7, 2, 6), flat(bodyColor));
  body.position.y = 0.8;
  const head = new THREE.Mesh(new THREE.IcosahedronGeometry(0.5, 0), flat(PALETTE.skin));
  head.position.y = 1.85;
  const hat = new THREE.Mesh(new THREE.CylinderGeometry(0.38, 0.32, 0.55, 7), flat(0xffffff));
  hat.position.y = 2.45;

  for (const part of [body, head, hat]) {
    part.castShadow = true;
    chef.add(part);
  }
  return chef;
}

function makeCounter(): THREE.Group {
  const counter = new THREE.Group();
  const base = box(3.2, 1.0, 1.2, PALETTE.counter);
  base.position.y = 0.5;
  const top = box(3.4, 0.12, 1.35, PALETTE.counterTop);
  top.position.y = 1.06;
  counter.add(base, top);
  return counter;
}

export interface Stage {
  scene: THREE.Scene;
  player: THREE.Group;
  rival: THREE.Group;
  plate: THREE.Mesh;
  /** Point above the rival's head, used to place the intent label. */
  rivalIntentAnchor: THREE.Object3D;
  update(time: number): void;
}

/**
 * Graybox cooking-show diorama: a raised stage seen from a high fixed camera,
 * two counters facing each other, crowd blocks in front.
 */
export function createStage(camera: THREE.PerspectiveCamera): Stage {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(PALETTE.background);
  scene.fog = new THREE.Fog(PALETTE.background, 30, 60);

  // Lighting: soft sky light + one sun for crisp diorama shadows.
  scene.add(new THREE.HemisphereLight(0xfff4e0, 0xc98a4b, 1.6));
  const sun = new THREE.DirectionalLight(0xffffff, 1.8);
  sun.position.set(-6, 12, 8);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -12, right: 12, top: 12, bottom: -12 });
  scene.add(sun);

  // Ground + stage platform.
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), flat(PALETTE.floor));
  floor.rotation.x = -Math.PI / 2;
  floor.receiveShadow = true;
  scene.add(floor);

  const stage = box(14, 0.6, 9, PALETTE.stage);
  stage.position.y = 0.3;
  const trim = box(14.2, 0.2, 9.2, PALETTE.stageTrim);
  trim.position.y = 0.05;
  scene.add(stage, trim);

  // Two counters facing each other: player front-left, rival back-right.
  const stageTop = 0.6;
  const playerCounter = makeCounter();
  playerCounter.position.set(-3, stageTop, 1.6);
  const rivalCounter = makeCounter();
  rivalCounter.position.set(3, stageTop, -1.6);
  scene.add(playerCounter, rivalCounter);

  const player = makeChef(PALETTE.player);
  // Both chefs stand behind their counters, facing the audience (cooking-show framing).
  player.position.set(-3, stageTop, 0.3);
  const rival = makeChef(PALETTE.rival);
  rival.position.set(3, stageTop, -3);
  scene.add(player, rival);

  // The Plate sits on the player's counter.
  const plate = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.45, 0.1, 10), flat(PALETTE.plate));
  plate.position.set(-3, stageTop + 1.17, 1.6);
  plate.castShadow = true;
  scene.add(plate);

  // Show banner at the back, accent color.
  const banner = box(5, 1.4, 0.2, PALETTE.accent);
  banner.position.set(0, 3.2, -5.5);
  scene.add(banner);
  for (const x of [-2.6, 2.6]) {
    const pole = box(0.2, 3.9, 0.2, PALETTE.stageTrim);
    pole.position.set(x, 1.95, -5.5);
    scene.add(pole);
  }

  // Crowd: silhouette blocks in front of the stage (GDD §7.1).
  const crowdMat = flat(PALETTE.crowd);
  const crowdGeo = new THREE.CapsuleGeometry(0.35, 0.5, 1, 5);
  const crowd: THREE.Mesh[] = [];
  for (let row = 0; row < 2; row++) {
    for (let i = 0; i < 16; i++) {
      const m = new THREE.Mesh(crowdGeo, crowdMat);
      m.position.set(-11 + i * 1.45 + (row % 2) * 0.7, 0.6 + row * 0.35, 6.2 + row * 1.2);
      m.userData.phase = Math.random() * Math.PI * 2;
      m.userData.baseY = m.position.y;
      scene.add(m);
      crowd.push(m);
    }
  }

  const rivalIntentAnchor = new THREE.Object3D();
  rivalIntentAnchor.position.set(0, 3.3, 0);
  rival.add(rivalIntentAnchor);

  // High diorama camera, looking down at the stage from the audience side.
  camera.position.set(0, 17, 19);
  camera.lookAt(0, 0.5, 0);

  return {
    scene,
    player,
    rival,
    plate,
    rivalIntentAnchor,
    update(time: number) {
      // Idle bob so the graybox feels alive.
      player.position.y = stageTop + Math.abs(Math.sin(time * 2.2)) * 0.06;
      rival.position.y = stageTop + Math.abs(Math.sin(time * 2.0 + 1)) * 0.06;
      for (const m of crowd) {
        m.position.y = m.userData.baseY + Math.max(0, Math.sin(time * 3 + m.userData.phase)) * 0.12;
      }
    },
  };
}
