import { defineConfig } from "vite";
import mkcert from "vite-plugin-mkcert";

// mkcert serves HTTPS on localhost with a locally-trusted cert. Required
// because Chrome caches HSTS for localhost when any prior project used
// HTTPS there (e.g. the game-jam-viii client), and will block plain HTTP.
//
// The Slot-hosted katana and torii are HTTPS, so no proxy is needed — the
// client makes direct HTTPS calls from 127.0.0.1 to api.cartridge.gg.
export default defineConfig({
  base: "./",
  plugins: [mkcert()],
  server: {
    port: 5173,
    strictPort: true,
    host: true,
  },
  build: {
    outDir: "dist",
    target: "es2022",
    sourcemap: true,
  },
});
