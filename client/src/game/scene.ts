import * as THREE from "three";
import { GRID_WIDTH, GRID_HEIGHT } from "../state/constants.js";

export const TILE_SIZE = 1;

export interface SceneBundle {
  scene: THREE.Scene;
  camera: THREE.OrthographicCamera;
  renderer: THREE.WebGLRenderer;
  raycaster: THREE.Raycaster;
  dispose: () => void;
}

export function createScene(canvas: HTMLCanvasElement): SceneBundle {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x0e0e14);

  const aspect = canvas.clientWidth / canvas.clientHeight || 1;
  const viewSize = Math.max(GRID_WIDTH, GRID_HEIGHT) * 0.75;
  const camera = new THREE.OrthographicCamera(
    -viewSize * aspect,
    viewSize * aspect,
    viewSize,
    -viewSize,
    0.1,
    200,
  );

  // Isometric-ish camera: look at grid center from 45° above, rotated 45° around Y.
  const centerX = (GRID_WIDTH - 1) * 0.5 * TILE_SIZE;
  const centerZ = (GRID_HEIGHT - 1) * 0.5 * TILE_SIZE;
  camera.position.set(centerX + 10, 12, centerZ + 10);
  camera.lookAt(centerX, 0, centerZ);

  const ambient = new THREE.AmbientLight(0xffffff, 0.55);
  scene.add(ambient);
  const dir = new THREE.DirectionalLight(0xffffff, 0.8);
  dir.position.set(8, 14, 6);
  scene.add(dir);

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(window.devicePixelRatio);
  renderer.setSize(canvas.clientWidth, canvas.clientHeight, false);

  const raycaster = new THREE.Raycaster();

  const resize = (): void => {
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (w === 0 || h === 0) return;
    renderer.setSize(w, h, false);
    const newAspect = w / h;
    camera.left = -viewSize * newAspect;
    camera.right = viewSize * newAspect;
    camera.updateProjectionMatrix();
  };
  const ro = new ResizeObserver(resize);
  ro.observe(canvas);

  const dispose = (): void => {
    ro.disconnect();
    renderer.dispose();
  };

  return { scene, camera, renderer, raycaster, dispose };
}
