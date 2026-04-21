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

// Deep indigo void — reads as an abyss under the floating islands.
const VOID_COLOR = 0x0b0820;

export function createScene(canvas: HTMLCanvasElement): SceneBundle {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(VOID_COLOR);
  scene.fog = new THREE.FogExp2(VOID_COLOR, 0.035);

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

  // Lighting: soft ambient + warm key + cool rim from behind the camera to
  // separate the islands from the void.
  const ambient = new THREE.AmbientLight(0xcacfe5, 0.45);
  scene.add(ambient);

  const key = new THREE.DirectionalLight(0xffe5c0, 0.9);
  key.position.set(centerX + 8, 14, centerZ + 6);
  scene.add(key);

  const rim = new THREE.DirectionalLight(0x6f8cff, 0.35);
  rim.position.set(centerX - 6, 5, centerZ - 8);
  scene.add(rim);

  // Faint glow disc far beneath the grid so the void has a hint of depth.
  const glowGeom = new THREE.CircleGeometry(18, 48);
  const glowMat = new THREE.MeshBasicMaterial({
    color: 0x1f1a45,
    transparent: true,
    opacity: 0.45,
  });
  const glow = new THREE.Mesh(glowGeom, glowMat);
  glow.rotation.x = -Math.PI / 2;
  glow.position.set(centerX, -6, centerZ);
  scene.add(glow);

  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
  renderer.setPixelRatio(window.devicePixelRatio);
  renderer.setSize(canvas.clientWidth, canvas.clientHeight, false);
  renderer.outputColorSpace = THREE.SRGBColorSpace;

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
    glowGeom.dispose();
    glowMat.dispose();
  };

  return { scene, camera, renderer, raycaster, dispose };
}
