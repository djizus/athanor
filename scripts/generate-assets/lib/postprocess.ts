import { NodeIO } from "@gltf-transform/core";
import { dedup, prune, textureCompress, weld } from "@gltf-transform/functions";
import sharp from "sharp";

/**
 * Mild postprocessing pass:
 *  - prune:  drop unused resources
 *  - dedup:  collapse duplicate accessors/textures/meshes
 *  - weld:   merge coincident vertices (lower tri count)
 *  - textureCompress: cap textures at 1024x1024 (preserves aspect ratio)
 *
 * No Draco/meshopt — keep the Three.js client loader vanilla.
 */
export async function postprocessGlb(glbIn: Buffer): Promise<Buffer> {
  const io = new NodeIO();
  // Buffer -> Uint8Array view is accepted by readBinary.
  const input = new Uint8Array(glbIn.buffer, glbIn.byteOffset, glbIn.byteLength);
  const doc = await io.readBinary(input);

  await doc.transform(
    prune(),
    dedup(),
    weld(),
    textureCompress({
      encoder: sharp,
      resize: [1024, 1024],
    }),
  );

  const output = await io.writeBinary(doc);
  return Buffer.from(output);
}
