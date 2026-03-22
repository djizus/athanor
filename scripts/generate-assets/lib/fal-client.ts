import * as fal from "@fal-ai/client";
import { FAL_KEY, MAX_RETRIES, REQUEST_DELAY_MS } from "./env.js";

fal.config({ credentials: FAL_KEY });

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export interface FalImageResult {
  url: string;
  width: number;
  height: number;
}

export async function generateImage(
  prompt: string,
  width: number = 1024,
  height: number = 1024
): Promise<FalImageResult> {
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const result = await fal.subscribe("fal-ai/flux/schnell", {
        input: {
          prompt,
          image_size: { width, height },
          num_images: 1,
          enable_safety_checker: false,
        },
      });
      const image = (result.data as any).images?.[0];
      if (!image?.url) throw new Error("No image URL in response");
      return { url: image.url, width: image.width || width, height: image.height || height };
    } catch (err: any) {
      const wait = [15, 30, 60, 120][attempt] ?? 120;
      console.error(`  FAL attempt ${attempt + 1}/${MAX_RETRIES} failed: ${err.message}. Retrying in ${wait}s...`);
      await sleep(wait * 1000);
    }
  }
  throw new Error(`FAL generation failed after ${MAX_RETRIES} attempts`);
}

export async function downloadImage(url: string): Promise<Buffer> {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Download failed: ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}
