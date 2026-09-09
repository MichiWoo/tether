import { defineConfig } from "vite";
import vue from "@vitejs/plugin-vue";
import { fileURLToPath, URL } from "node:url";
import { readFileSync } from "node:fs";

const pkg = JSON.parse(
  readFileSync(fileURLToPath(new URL("./package.json", import.meta.url)), "utf8"),
) as { version: string };

// https://vite.dev/config/
export default defineConfig({
  define: {
    // Versión de la app single-source (package.json), disponible como env en runtime.
    "import.meta.env.APP_VERSION": JSON.stringify(pkg.version),
  },
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
