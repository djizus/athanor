import { fal } from '@fal-ai/client';
import sharp from 'sharp';
import { writeFile, mkdir } from 'fs/promises';
import { dirname } from 'path';
import { requireFalKey, REQUEST_DELAY_MS, MAX_RETRIES, RETRY_DELAYS_MS } from './env';

let configured = false;

function ensureConfigured(): void {
  if (configured) return;
  requireFalKey();
  fal.config({ credentials: process.env['FAL_KEY'] });
  configured = true;
}

type ImageSizeName = 'square_hd' | 'landscape_16_9' | 'portrait_16_9' | 'landscape_4_3' | 'portrait_4_3' | 'square';
type ImageSize = ImageSizeName | { width: number; height: number };

function resolveImageSize(width: number, height: number): ImageSize {
  const standardSizes: Record<string, ImageSizeName> = {
    '1024x1024': 'square_hd',
    '1280x720': 'landscape_16_9',
    '720x1280': 'portrait_16_9',
    '1024x768': 'landscape_4_3',
    '768x1024': 'portrait_4_3',
  };
  const key = `${width}x${height}`;
  return standardSizes[key] ?? { width, height };
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function generateImage(
  prompt: string,
  width: number,
  height: number,
): Promise<Buffer> {
  ensureConfigured();

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const result = await fal.subscribe('fal-ai/flux-2-pro', {
        input: {
          prompt,
          image_size: resolveImageSize(width, height),
          safety_tolerance: '5',
          output_format: 'png',
        },
      });

      const imageUrl = result.data.images[0]?.url;
      if (!imageUrl) throw new Error('No image URL in response');

      const response = await fetch(imageUrl);
      if (!response.ok) throw new Error(`Failed to fetch image: ${response.status}`);

      const arrayBuffer = await response.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);

      await sleep(REQUEST_DELAY_MS);
      return buffer;
    } catch (err) {
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_DELAYS_MS[attempt] ?? 60_000;
        console.warn(`Attempt ${attempt + 1} failed, retrying in ${delay / 1000}s...`, err);
        await sleep(delay);
      } else {
        throw err;
      }
    }
  }

  throw new Error('Unreachable');
}

export async function generateSfx(
  prompt: string,
  durationSeconds: number,
): Promise<Buffer> {
  ensureConfigured();

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const result = await fal.subscribe('fal-ai/elevenlabs/sound-effects/v2', {
        input: {
          text: prompt,
          duration_seconds: durationSeconds,
          prompt_influence: 0.3,
          output_format: 'mp3_44100_192',
        },
      });

      const audio = result.data.audio as unknown as { url: string };
      const audioUrl = audio?.url;
      if (!audioUrl) throw new Error('No audio URL in response');

      const response = await fetch(audioUrl);
      if (!response.ok) throw new Error(`Failed to fetch audio: ${response.status}`);

      const arrayBuffer = await response.arrayBuffer();
      await sleep(REQUEST_DELAY_MS);
      return Buffer.from(arrayBuffer);
    } catch (err) {
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_DELAYS_MS[attempt] ?? 60_000;
        console.warn(`Attempt ${attempt + 1} failed, retrying in ${delay / 1000}s...`, err);
        await sleep(delay);
      } else {
        throw err;
      }
    }
  }

  throw new Error('Unreachable');
}

export async function savePng(buffer: Buffer, outputPath: string): Promise<void> {
  await mkdir(dirname(outputPath), { recursive: true });
  const pngBuffer = await sharp(buffer).png().toBuffer();
  await writeFile(outputPath, pngBuffer);
}

export async function saveWebp(buffer: Buffer, outputPath: string, quality = 85): Promise<void> {
  await mkdir(dirname(outputPath), { recursive: true });
  const webpBuffer = await sharp(buffer).webp({ quality }).toBuffer();
  await writeFile(outputPath, webpBuffer);
}

export async function saveFile(buffer: Buffer, outputPath: string): Promise<void> {
  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, buffer);
}

export async function resizeImage(
  buffer: Buffer,
  width: number,
  height: number,
): Promise<Buffer> {
  return sharp(buffer).resize(width, height, { fit: 'cover' }).png().toBuffer();
}

export async function uploadToFalStorage(buffer: Buffer): Promise<string> {
  ensureConfigured();
  const blob = new Blob([buffer], { type: 'image/png' });
  const url = await fal.storage.upload(blob);
  return url;
}

export async function decomposeImageLayers(
  imageUrl: string,
  numLayers: number,
): Promise<Buffer[]> {
  ensureConfigured();

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const result = await fal.subscribe('fal-ai/qwen-image-layered', {
        input: {
          image_url: imageUrl,
          num_layers: numLayers,
          num_inference_steps: 28,
          guidance_scale: 5.0,
          output_format: 'png',
        },
      });

      const images = result.data.images as Array<{ url: string }>;
      if (!images || images.length === 0) throw new Error('No layer images in response');

      const buffers: Buffer[] = [];
      for (const img of images) {
        const response = await fetch(img.url);
        if (!response.ok) throw new Error(`Failed to fetch layer image: ${response.status}`);
        const arrayBuffer = await response.arrayBuffer();
        buffers.push(Buffer.from(arrayBuffer));
      }

      await sleep(REQUEST_DELAY_MS);
      return buffers;
    } catch (err) {
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_DELAYS_MS[attempt] ?? 60_000;
        console.warn(`Attempt ${attempt + 1} failed, retrying in ${delay / 1000}s...`, err);
        await sleep(delay);
      } else {
        throw err;
      }
    }
  }

  throw new Error('Unreachable');
}

export async function generateVideo(
  imageUrl: string,
  prompt: string,
  width: number,
  height: number,
  fps: number,
  numFrames: number,
  format: 'webm' | 'gif' | 'mp4',
  cameraLora: string,
): Promise<Buffer> {
  ensureConfigured();

  const videoOutputType =
    format === 'webm' ? 'VP9 (.webm)' : format === 'gif' ? 'GIF (.gif)' : 'X264 (.mp4)';

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const result = await fal.subscribe('fal-ai/ltx-2-19b/image-to-video', {
        input: {
          image_url: imageUrl,
          end_image_url: imageUrl,
          prompt,
          camera_lora: cameraLora,
          video_output_type: videoOutputType,
          video_size: { width, height },
          fps,
          num_frames: numFrames,
        },
      });

      const video = result.data.video as unknown as { url: string };
      const videoUrl = video?.url;
      if (!videoUrl) throw new Error('No video URL in response');

      const response = await fetch(videoUrl);
      if (!response.ok) throw new Error(`Failed to fetch video: ${response.status}`);

      const arrayBuffer = await response.arrayBuffer();
      await sleep(REQUEST_DELAY_MS);
      return Buffer.from(arrayBuffer);
    } catch (err) {
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_DELAYS_MS[attempt] ?? 60_000;
        console.warn(`Attempt ${attempt + 1} failed, retrying in ${delay / 1000}s...`, err);
        await sleep(delay);
      } else {
        throw err;
      }
    }
  }

  throw new Error('Unreachable');
}
