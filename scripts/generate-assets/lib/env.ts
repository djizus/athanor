import fs from "node:fs";
import path from "node:path";
import type { LimitRunner, PLimitFactory } from "./types.js";

export const MESHY_API_BASE = "https://api.meshy.ai/openapi/v2";
export const MESHY_PROVIDER = "meshy" as const;

export const CONCURRENCY = 2;
export const REQUEST_DELAY_MS = 3_000;
export const POLL_INTERVAL_MS = 5_000;
export const POLL_MAX_TOTAL_MS = 15 * 60 * 1000; // 15 minutes per task
export const RETRY_BACKOFF_MS = [15_000, 30_000, 60_000, 120_000] as const;
export const MAX_RETRIES = RETRY_BACKOFF_MS.length;

export const ROOT_DIR = path.resolve(process.cwd());
export const CLIENT_MODELS_ROOT = path.join(ROOT_DIR, "client", "public", "models");
export const CACHE_ROOT = path.join(CLIENT_MODELS_ROOT, ".cache");
export const TASK_LOG_PATH = path.join(CACHE_ROOT, "task-log.jsonl");

export function loadEnvFromRoot(): void {
  const envPath = path.join(ROOT_DIR, ".env");
  if (!fs.existsSync(envPath)) return;

  const envContent = fs.readFileSync(envPath, "utf-8");
  for (const rawLine of envContent.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;

    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
    if (!match) continue;

    const key = match[1];
    const rawValue = match[2];
    if (key === undefined || rawValue === undefined) continue;
    if (process.env[key] !== undefined) continue;

    const value = rawValue.replace(/^['"]|['"]$/g, "");
    process.env[key] = value;
  }
}

loadEnvFromRoot();

export function getMeshyKey(): string {
  const key = process.env.MESHY_KEY ?? process.env.MESHY_API_KEY;
  if (!key) {
    throw new Error(
      "MESHY_KEY is required. Add it to the repo-root .env file (MESHY_KEY=msy_...)",
    );
  }
  return key;
}

export function relativePath(filePath: string): string {
  return path.relative(ROOT_DIR, filePath).replace(/\\/g, "/");
}

export function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

let requestSlotChain: Promise<void> = Promise.resolve();
let nextRequestAt = 0;

/**
 * Serialize API calls so we never fire faster than REQUEST_DELAY_MS between
 * consecutive requests globally. Concurrency is still controlled by p-limit.
 */
export async function waitForRequestSlot(): Promise<void> {
  let release: ((value?: void | PromiseLike<void>) => void) | undefined;
  const previous = requestSlotChain;
  requestSlotChain = new Promise<void>((resolve) => {
    release = resolve;
  });

  await previous;
  try {
    const now = Date.now();
    const waitMs = Math.max(0, nextRequestAt - now);
    if (waitMs > 0) await sleep(waitMs);
    nextRequestAt = Date.now() + REQUEST_DELAY_MS;
  } finally {
    if (release) release();
  }
}

export function createLimitFallback(concurrency: number): LimitRunner {
  if (!Number.isInteger(concurrency) || concurrency < 1) {
    throw new Error(`Invalid concurrency: ${concurrency}`);
  }

  let activeCount = 0;
  const queue: Array<() => void> = [];

  const runNext = (): void => {
    if (activeCount >= concurrency) return;
    const next = queue.shift();
    if (!next) return;
    activeCount += 1;
    next();
  };

  return async <T>(task: () => Promise<T>): Promise<T> =>
    new Promise<T>((resolve, reject) => {
      const execute = (): void => {
        Promise.resolve()
          .then(task)
          .then(resolve, reject)
          .finally(() => {
            activeCount -= 1;
            runNext();
          });
      };

      queue.push(execute);
      runNext();
    });
}

export async function loadPLimitFactory(): Promise<PLimitFactory> {
  try {
    const importer = new Function("specifier", "return import(specifier)") as (
      specifier: string,
    ) => Promise<unknown>;
    const moduleValue = (await importer("p-limit")) as { default?: unknown };
    if (typeof moduleValue.default === "function") {
      return moduleValue.default as PLimitFactory;
    }
  } catch {}

  console.warn("p-limit not installed; using built-in limiter fallback.");
  return createLimitFallback;
}

export function isRetryableError(error: unknown): boolean {
  const candidate = error as {
    status?: number;
    statusCode?: number;
    code?: number;
    response?: { status?: number };
    body?: { status?: number };
    message?: string;
  };
  const status =
    candidate.status ??
    candidate.statusCode ??
    candidate.code ??
    candidate.response?.status ??
    candidate.body?.status;
  if (
    status === 408 ||
    status === 409 ||
    status === 425 ||
    status === 429 ||
    status === 500 ||
    status === 502 ||
    status === 503 ||
    status === 504
  ) {
    return true;
  }

  const message = error instanceof Error ? error.message : String(candidate.message ?? error);
  return /(^|\D)(408|409|425|429|500|502|503|504)(\D|$)|rate\s*limit|quota|unavailable|high demand|timed?\s*out|overloaded|try again/i.test(
    message,
  );
}

export function formatError(error: unknown): string {
  if (error instanceof Error) return error.message;
  return String(error);
}

export function appendTaskLog(entry: Record<string, unknown>): void {
  try {
    fs.mkdirSync(path.dirname(TASK_LOG_PATH), { recursive: true });
    fs.appendFileSync(
      TASK_LOG_PATH,
      `${JSON.stringify({ ts: new Date().toISOString(), ...entry })}\n`,
    );
  } catch (error) {
    console.warn(`Failed to append to task log: ${formatError(error)}`);
  }
}
