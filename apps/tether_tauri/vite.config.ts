import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { fileURLToPath, URL } from "node:url";

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  // Tauri espera un puerto fijo y no limpia la pantalla en el backend.
  clearScreen: false,
  server: {
    port: 1420,
    strictPort: true,
    watch: {
      ignored: ["**/src-tauri/**"],
    },
  },
  // Por defecto el objetivo de Tauri es el sistema actual (no `web`),
  // por lo que optimizamos para webviews modernos.
  build: {
    target: "es2022",
    sourcemap: false,
  },
});
