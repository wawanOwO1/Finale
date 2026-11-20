import * as THREE from 'three';

/**
 * Wraps the WebGL renderer and handles:
 * - filling the whole window at any size (the jam tests 5 window sizes + live resizing)
 * - the optional pixel filter: render at a low resolution and let CSS upscale it
 *   with nearest-neighbor (`image-rendering: pixelated`).
 */
export class GameRenderer {
  readonly renderer: THREE.WebGLRenderer;
  readonly camera: THREE.PerspectiveCamera;
  private pixelated = false;
  /** Vertical resolution in "game pixels" when the pixel filter is on. */
  private readonly pixelHeight = 360;

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    this.renderer.shadowMap.enabled = true;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;

    this.camera = new THREE.PerspectiveCamera(30, 16 / 9, 0.1, 200);

    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  get isPixelated(): boolean {
    return this.pixelated;
  }

  setPixelated(on: boolean): void {
    this.pixelated = on;
    this.renderer.domElement.classList.toggle('pixelated', on);
    this.resize();
  }

  resize(): void {
    const w = window.innerWidth;
    const h = window.innerHeight;
    // Pixel ratio < 1 renders fewer pixels; CSS stretches the canvas back to full size.
    const ratio = this.pixelated ? this.pixelHeight / h : Math.min(window.devicePixelRatio, 2);
    this.renderer.setPixelRatio(ratio);
    this.renderer.setSize(w, h);

    const aspect = w / h;
    this.camera.aspect = aspect;
    // On narrow windows (e.g. 1024x640) widen the FOV so the whole stage stays visible.
    this.camera.fov = aspect < 1.7 ? 30 * (1.7 / aspect) ** 0.8 : 30;
    this.camera.updateProjectionMatrix();
  }

  render(scene: THREE.Scene): void {
    this.renderer.render(scene, this.camera);
  }
}
