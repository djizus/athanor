import "./shims.js";
import dotenv from "dotenv";
import { resolve, dirname } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenv.config({ path: resolve(__dirname, "..", ".env") });

export const FAL_KEY = process.env.FAL_KEY || "";
export const MESHY_API_KEY = process.env.MESHY_API_KEY || "";
export const CONCURRENCY = 2;
export const REQUEST_DELAY_MS = 3000;
export const MAX_RETRIES = 4;

if (!FAL_KEY) console.warn("WARNING: FAL_KEY not set in .env");
if (!MESHY_API_KEY) console.warn("WARNING: MESHY_API_KEY not set in .env");
