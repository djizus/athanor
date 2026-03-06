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
