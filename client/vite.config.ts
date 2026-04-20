import { defineConfig } from "vite";
import mkcert from "vite-plugin-mkcert";

// mkcert serves HTTPS on localhost with a locally-trusted cert. Required
// because Chrome caches HSTS for localhost when any prior project used
// HTTPS there (e.g. the game-jam-viii client), and will block plain HTTP.
export default defineConfig({
  base: "./",
  plugins: [mkcert()],
  server: {
    port: 5173,
    strictPort: true,
  },
  build: {
    outDir: "dist",
    target: "es2022",
    sourcemap: true,
  },
});
