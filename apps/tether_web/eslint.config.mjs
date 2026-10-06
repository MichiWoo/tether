// Config plana de ESLint generada por @nuxt/eslint (reglas Nuxt + Vue + TS).
// Ver `.nuxt/eslint.config.mjs` (autogenerado en `nuxt prepare`).
import withNuxt from './.nuxt/eslint.config.mjs'

export default withNuxt(
  {
    rules: {
      // Mark y Constellation son componentes de marca de una sola palabra, a propósito.
      'vue/multi-word-component-names': ['error', { ignores: ['Mark', 'Constellation'] }],
    },
  },
  {
    // Páginas y layouts de Nuxt son route-based: los nombres de una palabra son la convención.
    files: ['app/pages/**/*.vue', 'app/layouts/**/*.vue'],
    rules: {
      'vue/multi-word-component-names': 'off',
    },
  },
)
