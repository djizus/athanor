import * as THREE from "three";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";

const loader = new GLTFLoader();
const cache = new Map<string, Promise<THREE.Group>>();

/**
 * Load a GLB from the public `/models/...` served by Vite and cache the parsed
 * scene. Subsequent calls for the same URL reuse the cached scene. Consumers
 * should call `instantiateFrom` to get a fresh clone they can safely add to
 * the scene.
 */
export function loadModel(url: string): Promise<THREE.Group> {
  const existing = cache.get(url);
  if (existing) return existing;

  const promise = new Promise<THREE.Group>((resolve, reject) => {
    loader.load(
      url,
      (gltf) => resolve(gltf.scene),
      undefined,
      (err) => reject(err),
    );
  });
  cache.set(url, promise);
  return promise;
}

/**
 * Clone a loaded scene so the caller can position/tint their instance without
 * affecting other instances. Materials are cloned too so per-instance color
 * overrides do not leak between clones.
 */
export function instantiateFrom(source: THREE.Group): THREE.Group {
  const clone = source.clone(true);
  clone.traverse((obj) => {
    const mesh = obj as THREE.Mesh;
    if ((mesh as unknown as { isMesh?: boolean }).isMesh && mesh.material) {
      if (Array.isArray(mesh.material)) {
        mesh.material = mesh.material.map((m) => m.clone());
      } else {
        mesh.material = (mesh.material as THREE.Material).clone();
      }
    }
  });
  return clone;
}

/**
 * Fit a model into a target vertical height (in world units), centering it on
 * the XZ plane and grounding its base at y=0. Useful for making Meshy exports
 * line up with the 1 unit tile grid regardless of the mesh's native scale.
 */
export function fitAndGround(group: THREE.Group, targetHeight: number): void {
  const box = new THREE.Box3().setFromObject(group);
  const size = new THREE.Vector3();
  box.getSize(size);
  if (size.y <= 0) return;

  const scale = targetHeight / size.y;
  group.scale.setScalar(scale);

  // Recompute after scaling, then shift so base sits at y=0 and center on XZ.
  const scaledBox = new THREE.Box3().setFromObject(group);
  const scaledSize = new THREE.Vector3();
  scaledBox.getSize(scaledSize);
  const center = new THREE.Vector3();
  scaledBox.getCenter(center);

  group.position.x -= center.x;
  group.position.z -= center.z;
  group.position.y -= scaledBox.min.y;
}
