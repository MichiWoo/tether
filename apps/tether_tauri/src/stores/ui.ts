import { defineStore } from "pinia";
import { applyTheme, initialTheme, type ThemeMode } from "@/core/theme";

export type Section = "home" | "devices" | "clipboard" | "files";

export const useUiStore = defineStore("ui", {
  state: () => ({
    theme: initialTheme() as ThemeMode,
    section: "home" as Section,
  }),
  actions: {
    toggleTheme() {
      this.theme = this.theme === "dark" ? "light" : "dark";
      applyTheme(this.theme);
    },
    setSection(section: Section) {
      this.section = section;
    },
  },
});
