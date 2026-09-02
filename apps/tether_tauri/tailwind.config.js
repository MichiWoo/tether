/** @type {import('tailwindcss').Config} */
export default {
  darkMode: "class",
  content: ["./index.html", "./src/**/*.{vue,ts}"],
  theme: {
    extend: {
      colors: {
        bg: "rgb(var(--paper) / <alpha-value>)",
        fg: "rgb(var(--ink) / <alpha-value>)",
        muted: "rgb(var(--muted) / <alpha-value>)",
        "surface-2": "rgb(var(--gray-2) / <alpha-value>)",
        border: "rgb(var(--ink) / <alpha-value>)",
        primary: "rgb(var(--ink) / <alpha-value>)",
        "primary-fg": "rgb(var(--paper) / <alpha-value>)",
        secondary: "rgb(var(--ink) / <alpha-value>)",
        accent: "rgb(var(--ink) / <alpha-value>)",
        destructive: "rgb(var(--ink) / <alpha-value>)",
        success: "rgb(var(--ink) / <alpha-value>)",
        warning: "rgb(var(--ink) / <alpha-value>)",
        info: "rgb(var(--ink) / <alpha-value>)",
      },
      fontFamily: {
        sans: ["-apple-system", "BlinkMacSystemFont", "Segoe UI", "system-ui", "sans-serif"],
        display: ["Silkscreen", "system-ui", "sans-serif"],
        mono: ["'JetBrains Mono'", "ui-monospace", "monospace"],
      },
    },
  },
  plugins: [],
};
