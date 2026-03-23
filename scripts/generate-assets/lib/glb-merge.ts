import { NodeIO, Document, Animation, AnimationChannel, AnimationSampler, Accessor, Node as GltfNode, Material, Texture, Mesh, Primitive } from "@gltf-transform/core";

interface AnimationInput {
  name: string;
  glbPath: string;
  loop: boolean;
}

const io = new NodeIO();

export async function mergeAnimationsIntoModel(
  baseGlbPath: string,
  animations: AnimationInput[],
  outputPath: string,
  textureSourceGlbPath?: string,
): Promise<number> {
  const baseDoc = await io.read(baseGlbPath);

  if (textureSourceGlbPath) {
    await transferMaterials(baseDoc, textureSourceGlbPath);
  }
  const baseRoot = baseDoc.getRoot();
  const baseNodes = baseRoot.listNodes();
  const nodeNameMap = new Map<string, GltfNode>();
  for (const node of baseNodes) {
    const name = node.getName();
    if (name) nodeNameMap.set(name, node);
  }

  let mergedCount = 0;

  for (const animInput of animations) {
    try {
      const animDoc = await io.read(animInput.glbPath);
      const animRoot = animDoc.getRoot();
      const srcAnimations = animRoot.listAnimations();
      if (srcAnimations.length === 0) continue;

      const srcAnim = srcAnimations[0];
      const newAnim = baseDoc.createAnimation(animInput.name);

      for (const srcChannel of srcAnim.listChannels()) {
        const srcSampler = srcChannel.getSampler();
        const srcTargetNode = srcChannel.getTargetNode();
        if (!srcSampler || !srcTargetNode) continue;

        const targetName = srcTargetNode.getName();
        const baseNode = targetName ? nodeNameMap.get(targetName) : null;
        if (!baseNode) continue;

        const srcInput = srcSampler.getInput();
        const srcOutput = srcSampler.getOutput();
        if (!srcInput || !srcOutput) continue;

        const newInput = baseDoc.createAccessor()
          .setType(srcInput.getType())
          .setArray(srcInput.getArray()!.slice());
        const newOutput = baseDoc.createAccessor()
          .setType(srcOutput.getType())
          .setArray(srcOutput.getArray()!.slice());

        const newSampler = baseDoc.createAnimationSampler()
          .setInput(newInput)
          .setOutput(newOutput)
          .setInterpolation(srcSampler.getInterpolation());

        const newChannel = baseDoc.createAnimationChannel()
          .setSampler(newSampler)
          .setTargetNode(baseNode)
          .setTargetPath(srcChannel.getTargetPath()!);

        newAnim.addSampler(newSampler);
        newAnim.addChannel(newChannel);
      }

      mergedCount++;
    } catch (err: any) {
      console.warn(`  Failed to merge animation "${animInput.name}": ${err.message}`);
    }
  }

  await io.write(outputPath, baseDoc);
  return mergedCount;
}

async function transferMaterials(targetDoc: Document, sourceGlbPath: string): Promise<void> {
  const srcDoc = await io.read(sourceGlbPath);
  const srcMats = srcDoc.getRoot().listMaterials();
  if (srcMats.length === 0) return;

  const srcMat = srcMats[0];
  const newMat = targetDoc.createMaterial(srcMat.getName() || "PBR_Material");
  newMat.setBaseColorFactor(srcMat.getBaseColorFactor());
  newMat.setMetallicFactor(srcMat.getMetallicFactor());
  newMat.setRoughnessFactor(srcMat.getRoughnessFactor());
  newMat.setDoubleSided(srcMat.getDoubleSided());
  newMat.setAlphaMode(srcMat.getAlphaMode());

  const copyTexture = (srcTex: Texture | null): Texture | null => {
    if (!srcTex) return null;
    const img = srcTex.getImage();
    if (!img) return null;
    const newTex = targetDoc.createTexture(srcTex.getName() || "texture");
    newTex.setImage(img);
    newTex.setMimeType(srcTex.getMimeType());
    return newTex;
  };

  const baseColorTex = copyTexture(srcMat.getBaseColorTexture());
  if (baseColorTex) newMat.setBaseColorTexture(baseColorTex);

  const mrTex = copyTexture(srcMat.getMetallicRoughnessTexture());
  if (mrTex) newMat.setMetallicRoughnessTexture(mrTex);

  const normalTex = copyTexture(srcMat.getNormalTexture());
  if (normalTex) newMat.setNormalTexture(normalTex);

  const emissiveTex = copyTexture(srcMat.getEmissiveTexture());
  if (emissiveTex) newMat.setEmissiveTexture(emissiveTex);
  newMat.setEmissiveFactor(srcMat.getEmissiveFactor());

  const occTex = copyTexture(srcMat.getOcclusionTexture());
  if (occTex) newMat.setOcclusionTexture(occTex);

  for (const mesh of targetDoc.getRoot().listMeshes()) {
    for (const prim of mesh.listPrimitives()) {
      prim.setMaterial(newMat);
    }
  }
}
