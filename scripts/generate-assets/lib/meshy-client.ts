import "./shims.js";
import { MESHY_API_KEY, MAX_RETRIES } from "./env.js";

const MESHY_BASE = "https://api.meshy.ai/openapi/v1";
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

interface MeshyTaskResponse {
  result: string;
}

interface MeshyStatusResponse {
  id: string;
  status: "PENDING" | "IN_PROGRESS" | "SUCCEEDED" | "FAILED" | "EXPIRED";
  model_urls?: { glb?: string; fbx?: string; obj?: string };
  progress?: number;
  task_error?: { message?: string };
}

export async function createImageTo3D(
  imageUrl: string,
  options: {
    targetPolycount?: number;
    topology?: "quad" | "triangle";
    enablePbr?: boolean;
  } = {}
): Promise<string> {
  const body = {
    image_url: imageUrl,
    enable_pbr: options.enablePbr ?? true,
    ai_model: "meshy-6",
    topology: options.topology ?? "quad",
    target_polycount: options.targetPolycount ?? 10000,
    should_remesh: true,
    target_formats: ["glb"],
  };

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
