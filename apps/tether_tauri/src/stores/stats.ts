import { defineStore } from "pinia";
import { ENDPOINTS, http } from "@/core/http";
import type { Stats } from "@/core/types";

export const useStatsStore = defineStore("stats", {
  state: () => ({
    stats: null as Stats | null,
    isLoading: false,
    error: null as string | null,
  }),

  actions: {
    async load() {
      this.isLoading = true;
      this.error = null;
      try {
        const res = await http.get<Stats>(ENDPOINTS.stats);
        this.stats = res.data ?? null;
      } catch {
        this.error = "No se pudieron cargar las estadísticas.";
      } finally {
        this.isLoading = false;
      }
    },
  },
});
