export type ThemeMode = "dark" | "light";

const STORAGE_KEY = "tether.theme";

export function applyTheme(mode: ThemeMode): void {
  const el = document.documentElement;
  el.classList.toggle("dark", mode === "dark");
  el.classList.toggle("light", mode === "light");
  try {
    localStorage.setItem(STORAGE_KEY, mode);
  } catch {
    /* ignore */
  }
}

export function initialTheme(): ThemeMode {
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved === "dark" || saved === "light") return saved;
  } catch {
    /* ignore */
  }
  return "dark";
}
