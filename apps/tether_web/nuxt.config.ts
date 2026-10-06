// Tether — landing + panel admin. SSG con `nuxt generate`: HTML estático
// para la landing y JS hidratado para demo, descargas y panel.
// API_BASE vacío en prod = mismo origen vía proxy nginx (ver nginx.conf).
import { readdirSync } from 'node:fs'
import { fileURLToPath } from 'node:url'

// Resuelve el entry ESM real de un paquete en el store pnpm del monorepo, sin fijar
// versión (tolera bumps). Se usa para aliasar a ruta ABSOLUTA: así se salta el campo
// `exports` del paquete (eventemitter3 no expone el subpath ./index.mjs) y se fuerza el
// ESM, que Vite en dev serviría como CJS (index.js) rompiendo `import { EventEmitter }`.
function pnpmEsmEntry(pkg: string, file: string): string {
  const store = fileURLToPath(new URL('../../node_modules/.pnpm', import.meta.url))
  const dir = readdirSync(store).find(d => d.startsWith(`${pkg}@`))
  if (!dir) throw new Error(`[nuxt.config] no se encontró "${pkg}" en ${store}`)
  return `${store}/${dir}/node_modules/${pkg}/${file}`
}

export default defineNuxtConfig({
  compatibilityDate: '2026-09-01',
  devtools: { enabled: false },
  ssr: true,
  modules: ['@nuxt/ui', 'nuxt-charts', '@nuxt/eslint'],
  css: ['~/assets/css/main.css'],
  // El mundo Tether es dark-first: fija el modo oscuro para que los componentes de
  // Nuxt UI (inputs, selects, cards) rendericen con su paleta oscura sobre --paper.
  colorMode: {
    preference: 'dark',
    fallback: 'dark',
  },
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE_URL ?? '',
      // Origen público de la landing (para URLs absolutas: canonical, og:url, og:image).
      siteUrl: process.env.NUXT_PUBLIC_SITE_URL ?? 'https://tether.app',
    },
  },
  app: {
    head: {
      htmlAttrs: { lang: 'es' },
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1.0' },
        { name: 'theme-color', content: '#282a36' },
      ],
      link: [{ rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
    },
  },
  nitro: {
    output: { publicDir: 'dist' },
  },
  vite: {
    // Deps de nuxt-charts → vccs con interop CJS/ESM que Vite no resuelve bien:
    // - decimal.js-light: sin `exports` y `main` CJS → shim local al .mjs. Regex de match
    //   EXACTO (no objeto) para no re-aliasar el `export * from 'decimal.js-light/decimal.mjs'`
    //   interno del shim (con prefijo daba `.../decimal.js-light.mjs/decimal.mjs` → "not a
    //   directory" y rompía `nuxt generate`).
    // - eventemitter3: alias a la ruta ABSOLUTA de su index.mjs (ver pnpmEsmEntry). En build
    //   rolldown ya elegiría el ESM por `exports`, pero en dev Vite servía el index.js (CJS)
    //   y fallaba `import { EventEmitter }`; la ruta directa fuerza el ESM en ambos.
    resolve: {
      alias: [
        { find: /^decimal\.js-light$/, replacement: fileURLToPath(new URL('./app/shims/decimal.js-light.mjs', import.meta.url)) },
        { find: /^eventemitter3$/, replacement: pnpmEsmEntry('eventemitter3', 'index.mjs') },
      ],
    },
    // nuxt-charts (vccs) mezcla deps CJS sin exports ESM: en dev hay que
    // pre-bundlearlos (cliente) y sacarlos de la externalización SSR.
    optimizeDeps: {
      include: ['nuxt-charts', 'vccs', 'motion-v'],
    },
  },
  typescript: {
    strict: true,
    typeCheck: false,
  },
})
