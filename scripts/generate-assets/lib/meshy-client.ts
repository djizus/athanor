import fs from "node:fs";
import path from "node:path";
import {
  MAX_RETRIES,
  MESHY_API_BASE,
  POLL_INTERVAL_MS,
  POLL_MAX_TOTAL_MS,
  RETRY_BACKOFF_MS,
  appendTaskLog,
  formatError,
  getMeshyKey,
  isRetryableError,
  sleep,
  waitForRequestSlot,
} from "./env.js";
import type {
  AssetJob3D,
  MeshyPreviewRequest,
  MeshyRefineRequest,
  MeshyResult,
  MeshyTaskResponse,
} from "./types.js";

async function meshyRequest<T>(
  method: "GET" | "POST" | "DELETE",
  url: string,
  body?: unknown,
): Promise<T> {
  const key = getMeshyKey();
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt += 1) {
    try {
      await waitForRequestSlot();

      const response = await fetch(url, {
        method,
        headers: {
          Authorization: `Bearer ${key}`,
          "Content-Type": "application/json",
        },
        body: body !== undefined ? JSON.stringify(body) : undefined,
      });

      if (!response.ok) {
        const text = await response.text().catch(() => "");
        const err = new Error(`Meshy ${method} ${url} -> ${response.status} ${text}`);
        (err as { status?: number }).status = response.status;
        throw err;
      }

      if (response.status === 204) return undefined as unknown as T;

      return (await response.json()) as T;
    } catch (error) {
      if (isRetryableError(error) && attempt < MAX_RETRIES) {
        const backoffMs =
          RETRY_BACKOFF_MS[attempt] ?? RETRY_BACKOFF_MS[RETRY_BACKOFF_MS.length - 1] ?? 30_000;
        console.warn(`   retryable (attempt ${attempt + 1}): ${formatError(error)} — retrying in ${Math.round(backoffMs / 1000)}s`);
        await sleep(backoffMs);
        continue;
      }
      throw error;
    }
  }
  throw new Error("Meshy request failed after retries.");
}

async function createPreviewTask(job: AssetJob3D): Promise<string> {
  const body: MeshyPreviewRequest = {
    mode: "preview",
    prompt: job.prompt,
    model_type: "lowpoly",
    target_polycount: job.polycount,
    symmetry_mode: "auto",
    auto_size: true,
    origin_at: "bottom",
    target_formats: ["glb"],
    ...(job.pose ? { pose_mode: job.pose } : {}),
  };
  const res = await meshyRequest<{ result: string }>(
    "POST",
    `${MESHY_API_BASE}/text-to-3d`,
    body,
  );
  appendTaskLog({ event: "preview_created", job_id: job.id, task_id: res.result });
  return res.result;
}

async function createRefineTask(previewTaskId: string): Promise<string> {
  const body: MeshyRefineRequest = {
    mode: "refine",
    preview_task_id: previewTaskId,
    enable_pbr: true,
    remove_lighting: true,
    target_formats: ["glb"],
    auto_size: true,
    origin_at: "bottom",
  };
  const res = await meshyRequest<{ result: string }>(
    "POST",
    `${MESHY_API_BASE}/text-to-3d`,
    body,
  );
  appendTaskLog({ event: "refine_created", preview_task_id: previewTaskId, task_id: res.result });
  return res.result;
}

async function getTask(taskId: string): Promise<MeshyTaskResponse> {
  return meshyRequest<MeshyTaskResponse>(
    "GET",
    `${MESHY_API_BASE}/text-to-3d/${taskId}`,
  );
}

async function pollUntilDone(taskId: string, label: string): Promise<MeshyTaskResponse> {
  const startedAt = Date.now();
  let lastProgress = -1;
  while (true) {
    const task = await getTask(taskId);
    if (task.progress !== lastProgress) {
      const elapsed = ((Date.now() - startedAt) / 1000).toFixed(0);
      console.log(`   [${label} ${taskId.slice(0, 8)}] ${task.status} ${task.progress}% (${elapsed}s)`);
      lastProgress = task.progress;
    }
    if (task.status === "SUCCEEDED") {
      appendTaskLog({ event: "task_succeeded", task_id: taskId, label });
      return task;
    }
    if (task.status === "FAILED" || task.status === "CANCELED") {
      appendTaskLog({
        event: "task_failed",
        task_id: taskId,
        label,
        status: task.status,
        error: task.task_error?.message,
      });
      throw new Error(
        `Meshy ${label} task ${taskId} ${task.status}: ${task.task_error?.message ?? "unknown error"}`,
      );
    }
    if (Date.now() - startedAt > POLL_MAX_TOTAL_MS) {
      throw new Error(`Meshy ${label} task ${taskId} timed out after ${POLL_MAX_TOTAL_MS / 1000}s`);
    }
    await sleep(POLL_INTERVAL_MS);
  }
}

async function downloadToBuffer(url: string): Promise<Buffer> {
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt += 1) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        const err = new Error(`Download failed (${response.status}) for ${url}`);
        (err as { status?: number }).status = response.status;
        throw err;
      }
      const buffer = Buffer.from(await response.arrayBuffer());
      if (buffer.byteLength === 0) {
        throw new Error("Downloaded file is empty");
      }
      return buffer;
    } catch (error) {
      if (isRetryableError(error) && attempt < MAX_RETRIES) {
        const backoffMs =
          RETRY_BACKOFF_MS[attempt] ?? RETRY_BACKOFF_MS[RETRY_BACKOFF_MS.length - 1] ?? 30_000;
        console.warn(`   download retryable (attempt ${attempt + 1}): ${formatError(error)} — retrying in ${Math.round(backoffMs / 1000)}s`);
        await sleep(backoffMs);
        continue;
      }
      throw error;
    }
  }
  throw new Error("Download failed after retries.");
}

export interface GenerateModelOptions {
  previewOnly: boolean;
  cacheGlbPath: string;
}

export async function generateModel(
  job: AssetJob3D,
  options: GenerateModelOptions,
): Promise<MeshyResult> {
  // --- Preview stage ---
  console.log(`   > Creating preview task (polycount ${job.polycount}${job.pose ? `, pose ${job.pose}` : ""})...`);
  const previewTaskId = await createPreviewTask(job);
  const preview = await pollUntilDone(previewTaskId, "preview");

  if (!preview.model_urls?.glb) {
    throw new Error(`Preview task ${previewTaskId} finished without a GLB URL.`);
  }

  if (options.previewOnly) {
    const glb = await downloadToBuffer(preview.model_urls.glb);
    fs.mkdirSync(path.dirname(options.cacheGlbPath), { recursive: true });
    fs.writeFileSync(options.cacheGlbPath, glb);
    const thumb = preview.thumbnail_url ? await downloadToBuffer(preview.thumbnail_url) : undefined;
    return { glbBuffer: glb, thumbBuffer: thumb, previewTaskId };
  }

  // --- Refine stage ---
  console.log(`   > Creating refine task (PBR, remove_lighting)...`);
  const refineTaskId = await createRefineTask(previewTaskId);
  const refined = await pollUntilDone(refineTaskId, "refine");

  if (!refined.model_urls?.glb) {
    throw new Error(`Refine task ${refineTaskId} finished without a GLB URL.`);
  }

  const glb = await downloadToBuffer(refined.model_urls.glb);
  fs.mkdirSync(path.dirname(options.cacheGlbPath), { recursive: true });
  fs.writeFileSync(options.cacheGlbPath, glb);
  const thumb = refined.thumbnail_url ? await downloadToBuffer(refined.thumbnail_url) : undefined;

  return { glbBuffer: glb, thumbBuffer: thumb, previewTaskId, refineTaskId };
}
