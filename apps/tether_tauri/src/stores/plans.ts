import { defineStore } from "pinia";
import { ENDPOINTS, http } from "@/core/http";
import type { PlanName, PlanUsageResponse } from "@tether/protocol";

export const usePlansStore = defineStore("plans", {
  state: () => ({
    usage: null as PlanUsageResponse | null,
    isLoading: false,
    error: null as string | null,
  }),

  getters: {
    storagePct: (s) => (s.usage ? Math.min(100, Math.round((s.usage.storageUsedBytes / s.usage.limits.maxStorageBytes) * 100)) : 0),
    transferPct: (s) => (s.usage ? Math.min(100, Math.round((s.usage.transferUsedThisMonthBytes / s.usage.limits.monthlyTransferBytes) * 100)) : 0),
    devicesPct: (s) => (s.usage ? Math.min(100, Math.round((s.usage.devicesUsed / s.usage.limits.maxDevices) * 100)) : 0),
    storageNearLimit: (s) => s.usage !== null && s.usage.storageUsedBytes / s.usage.limits.maxStorageBytes >= 0.8,
    transferNearLimit: (s) => s.usage !== null && s.usage.transferUsedThisMonthBytes / s.usage.limits.monthlyTransferBytes >= 0.8,
  },

  actions: {
    async load() {
      this.isLoading = true;
      this.error = null;
      try {
        const res = await http.get<PlanUsageResponse>(ENDPOINTS.meUsage);
        this.usage = res.data ?? null;
      } catch {
        this.error = "No se pudo cargar el uso del plan.";
      } finally {
        this.isLoading = false;
      }
    },

    async setPlan(plan: PlanName): Promise<boolean> {
      this.isLoading = true;
      this.error = null;
      try {
        await http.put<{ plan: PlanName }>(ENDPOINTS.mePlan, { plan });
        await this.load();
        return true;
      } catch {
        this.error = "No se pudo cambiar el plan.";
        return false;
      } finally {
        this.isLoading = false;
      }
    },
  },
});
