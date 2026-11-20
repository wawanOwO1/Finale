import { defineConfig } from 'vite';

// base './' = relative paths, so the build works from any folder OpenGame serves it in.
export default defineConfig({
  base: './',
  build: { outDir: 'dist', assetsInlineLimit: 0 },
  server: { port: 5173 },
});
