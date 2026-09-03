import { defineConfig } from 'astro/config';
import { fileURLToPath } from 'node:url';

// Landing estática de Tether. Sin JS por defecto (solo la constelación y el menú móvil).
export default defineConfig({
  output: 'static',
  compressHTML: true,
  vite: {
    resolve: {
      alias: {
        '@': fileURLToPath(new URL('./src', import.meta.url)),
      },
    },
  },
});
