import "./shims.js";
import { writeFile } from "fs/promises";
import { MESHY_API_KEY, MAX_RETRIES } from "./env.js";

const MESHY_BASE = "https://api.meshy.ai/openapi/v1";
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

type MeshyStatus = "PENDING" | "IN_PROGRESS" | "SUCCEEDED" | "FAILED" | "EXPIRED";

interface MeshyTaskResponse {
  result: string;
}

interface MeshyStatusResponse {
  id: string;
  status: MeshyStatus;
  model_urls?: { glb?: string; fbx?: string; obj?: string };
  progress?: number;
  task_error?: { message?: string };
}

export interface RiggingResult {
  id: string;
  status: MeshyStatus;
  result?: {
    rigged_character_glb_url?: string;
    basic_animations?: {
      walking_glb_url?: string;
      running_glb_url?: string;
    };
  };
  task_error?: { message?: string };
}

export interface AnimationResult {
  id: string;
  status: MeshyStatus;
  result?: {
    animation_glb_url?: string;
  };
  task_error?: { message?: string };
}

export class MeshyPoseError extends Error {
  constructor(message: string) { super(message); this.name = "MeshyPoseError"; }
}

export async function createImageTo3D(
  imageUrl: string,
  options: {
    targetPolycount?: number;
    topology?: "quad" | "triangle";
    enablePbr?: boolean;
    poseMode?: "a-pose" | "t-pose" | "";
  } = {}
): Promise<string> {
  const body: Record<string, any> = {
    image_url: imageUrl,
    enable_pbr: options.enablePbr ?? true,
    ai_model: "meshy-6",
    topology: options.topology ?? "quad",
    target_polycount: options.targetPolycount ?? 10000,
    should_remesh: true,
    target_formats: ["glb"],
  };
  if (options.poseMode) {
    body.pose_mode = options.poseMode;
  }

  const res = await fetch(`${MESHY_BASE}/image-to-3d`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${MESHY_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Meshy create failed (${res.status}): ${text}`);
  }

  const data = (await res.json()) as MeshyTaskResponse;
  return data.result;
}

export async function pollTask(taskId: string, timeoutMs: number = 300_000): Promise<MeshyStatusResponse> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const res = await fetch(`${MESHY_BASE}/image-to-3d/${taskId}`, {
      headers: { Authorization: `Bearer ${MESHY_API_KEY}` },
    });
    if (!res.ok) throw new Error(`Meshy poll failed: ${res.status}`);
    const data = (await res.json()) as MeshyStatusResponse;

    if (data.status === "SUCCEEDED") return data;
    if (data.status === "FAILED" || data.status === "EXPIRED") {
      throw new Error(`Meshy task ${taskId} ${data.status}: ${data.task_error?.message ?? "unknown"}`);
    }

    const progress = data.progress ?? 0;
    process.stdout.write(`\r  Meshy progress: ${progress}%`);
    await sleep(5000);
  }
  throw new Error(`Meshy task ${taskId} timed out after ${timeoutMs / 1000}s`);
}

export async function downloadGlb(url: string): Promise<Buffer> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`GLB download failed: ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

export async function generateModel(
  imageUrl: string,
  options?: { targetPolycount?: number; topology?: "quad" | "triangle" }
): Promise<Buffer> {
  const taskId = await createImageTo3D(imageUrl, options);
  console.log(`  Meshy task created: ${taskId}`);
  const result = await pollTask(taskId);
  console.log(`\n  Meshy task completed`);

  const glbUrl = result.model_urls?.glb;
  if (!glbUrl) throw new Error("No GLB URL in Meshy result");
  return downloadGlb(glbUrl);
}

export async function createRigging(modelUrl: string, heightMeters: number = 1.7): Promise<string> {
  const res = await fetch(`${MESHY_BASE}/rigging`, {
    method: "POST",
    headers: { Authorization: `Bearer ${MESHY_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model_url: modelUrl, height_meters: heightMeters }),
  });
  if (res.status === 422) {
    const text = await res.text();
    throw new MeshyPoseError(`Pose estimation failed (422): ${text}`);
  }
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Meshy rigging create failed (${res.status}): ${text}`);
  }
  const data = (await res.json()) as MeshyTaskResponse;
  return data.result;
}

export async function pollRigging(taskId: string, timeoutMs: number = 600_000): Promise<RiggingResult> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const res = await fetch(`${MESHY_BASE}/rigging/${taskId}`, {
      headers: { Authorization: `Bearer ${MESHY_API_KEY}` },
    });
    if (!res.ok) throw new Error(`Meshy rigging poll failed: ${res.status}`);
    const data = (await res.json()) as RiggingResult;
    if (data.status === "SUCCEEDED") return data;
    if (data.status === "FAILED" || data.status === "EXPIRED") {
      throw new Error(`Rigging ${taskId} ${data.status}: ${data.task_error?.message ?? "unknown"}`);
    }
    process.stdout.write(`\r  Rigging progress...`);
    await sleep(5000);
  }
  throw new Error(`Rigging ${taskId} timed out after ${timeoutMs / 1000}s`);
}

export async function createAnimation(rigTaskId: string, actionId: number): Promise<string> {
  const res = await fetch(`${MESHY_BASE}/animations`, {
    method: "POST",
    headers: { Authorization: `Bearer ${MESHY_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ rig_task_id: rigTaskId, action_id: actionId }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Meshy animation create failed (${res.status}): ${text}`);
  }
  const data = (await res.json()) as MeshyTaskResponse;
  return data.result;
}

export async function pollAnimation(taskId: string, timeoutMs: number = 600_000): Promise<AnimationResult> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const res = await fetch(`${MESHY_BASE}/animations/${taskId}`, {
      headers: { Authorization: `Bearer ${MESHY_API_KEY}` },
    });
    if (!res.ok) throw new Error(`Meshy animation poll failed: ${res.status}`);
    const data = (await res.json()) as AnimationResult;
    if (data.status === "SUCCEEDED") return data;
    if (data.status === "FAILED" || data.status === "EXPIRED") {
      throw new Error(`Animation ${taskId} ${data.status}: ${data.task_error?.message ?? "unknown"}`);
    }
    process.stdout.write(".");
    await sleep(5000);
  }
  throw new Error(`Animation ${taskId} timed out after ${timeoutMs / 1000}s`);
}

export async function downloadToFile(url: string, destPath: string): Promise<void> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Download failed (${res.status}): ${url}`);
  const buffer = Buffer.from(await res.arrayBuffer());
  await writeFile(destPath, buffer);
}

export async function rigAndAnimate(
  modelUrl: string,
  animationActions: Array<{ name: string; actionId: number }>,
  heightMeters: number = 1.7,
): Promise<{
  rigTaskId: string;
  riggedGlbUrl: string;
  walkingGlbUrl: string;
  runningGlbUrl: string;
  animations: Record<string, { taskId: string; glbUrl: string }>;
}> {
  console.log(`  Creating rig task...`);
  const rigTaskId = await createRigging(modelUrl, heightMeters);
  console.log(`  Rig task: ${rigTaskId}`);
  const rigResult = await pollRigging(rigTaskId);
  console.log(`\n  Rigging complete`);

  const riggedGlbUrl = rigResult.result?.rigged_character_glb_url ?? "";
  const walkingGlbUrl = rigResult.result?.basic_animations?.walking_glb_url ?? "";
  const runningGlbUrl = rigResult.result?.basic_animations?.running_glb_url ?? "";

  const animations: Record<string, { taskId: string; glbUrl: string }> = {};
  for (const { name, actionId } of animationActions) {
    console.log(`  Generating animation: ${name} (action ${actionId})...`);
    const animTaskId = await createAnimation(rigTaskId, actionId);
    const animResult = await pollAnimation(animTaskId);
    const glbUrl = animResult.result?.animation_glb_url ?? "";
    animations[name] = { taskId: animTaskId, glbUrl };
    console.log(`\n  Animation ${name} complete`);
  }

  return { rigTaskId, riggedGlbUrl, walkingGlbUrl, runningGlbUrl, animations };
}
