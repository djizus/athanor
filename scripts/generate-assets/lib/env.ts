import { config } from 'dotenv';
config();

export const FAL_KEY = process.env['FAL_KEY'] ?? '';
export const REQUEST_DELAY_MS = 3000;
export const MAX_CONCURRENCY = 2;
export const MAX_RETRIES = 4;
export const RETRY_DELAYS_MS = [15_000, 30_000, 60_000, 120_000];

export function requireFalKey(): string {
  if (!FAL_KEY) {
    console.error('FAL_KEY not set. Add it to .env at project root.');
    process.exit(1);
  }
  return FAL_KEY;
}
