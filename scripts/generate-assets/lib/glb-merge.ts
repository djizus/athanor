import { NodeIO, Document, Animation, AnimationChannel, AnimationSampler, Accessor, Node as GltfNode } from "@gltf-transform/core";

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
): Promise<number> {
  const baseDoc = await io.read(baseGlbPath);
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
