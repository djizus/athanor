import "./shims.js";
import { createFalClient } from "@fal-ai/client";
import { FAL_KEY, MAX_RETRIES } from "./env.js";

const fal = createFalClient({ credentials: FAL_KEY });

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export interface FalImageResult {
  url: string;
  width: number;
  height: number;
}

type Resolution = "0.5K" | "1K" | "2K" | "4K";

export async function generateSpriteSheet(
  prompt: string,
  resolution: Resolution = "2K",
  referenceImageUrl?: string,
): Promise<FalImageResult> {
  const endpoint = referenceImageUrl
    ? "fal-ai/nano-banana-pro/edit"
    : "fal-ai/nano-banana-2";

  const input: Record<string, any> = {
    prompt,
    aspect_ratio: "1:1",
    resolution,
    num_images: 1,
    output_format: "png",
    safety_tolerance: "4",
  };
  if (referenceImageUrl) {
    input.image_urls = [referenceImageUrl];
  } else {
    input.expand_prompt = true;
  }

  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const result = await fal.subscribe(endpoint, {
        input,
        pollInterval: 2000,
        onQueueUpdate: (u: any) => {
          if (u.status === "IN_QUEUE") process.stdout.write(".");
        },
      });
      const image = (result.data as any).images?.[0];
      if (!image?.url) throw new Error("No image URL in response");
      return { url: image.url, width: image.width || 2048, height: image.height || 2048 };
    } catch (err: any) {
      const wait = [15, 30, 60, 120][attempt] ?? 120;
      console.error(`\n  FAL attempt ${attempt + 1}/${MAX_RETRIES} failed: ${err.message}. Retrying in ${wait}s...`);
      await sleep(wait * 1000);
    }
  }
  throw new Error(`Sprite sheet generation failed after ${MAX_RETRIES} attempts`);
}

export async function removeBackgroundAI(imageUrl: string): Promise<string> {
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const result = await fal.subscribe("fal-ai/birefnet/v2", {
        input: {
          image_url: imageUrl,
          model: "General Use (Light)",
          operating_resolution: "1024x1024",
          refine_foreground: true,
          output_format: "png",
        },
        pollInterval: 1500,
      });
      const outputUrl = (result.data as any).image?.url;
      if (!outputUrl) throw new Error("No output URL from birefnet");
      return outputUrl;
    } catch (err: any) {
      const wait = [10, 20, 40][attempt] ?? 40;
      console.error(`  BiRefNet attempt ${attempt + 1}/${MAX_RETRIES} failed: ${err.message}. Retrying in ${wait}s...`);
      await sleep(wait * 1000);
    }
  }
  throw new Error(`Background removal failed after ${MAX_RETRIES} attempts`);
}

export async function generateImage(
  prompt: string,
  width: number = 1024,
  height: number = 1024
): Promise<FalImageResult> {
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    try {
      const result = await fal.subscribe("fal-ai/flux/schnell", {
        input: { prompt, image_size: { width, height }, num_images: 1, enable_safety_checker: false },
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
