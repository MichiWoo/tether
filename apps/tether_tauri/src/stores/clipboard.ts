import { defineStore } from "pinia";
import { ENDPOINTS, http } from "@/core/http";
import { realtime, RealtimeEvents } from "@/core/realtime";
import { deviceStorage } from "@/core/storage";
import { writeClipboard } from "@/core/clipboard";
import type { ClipboardItem } from "@/core/types";

export const useClipboardStore = defineStore("clipboard", {
  state: () => ({
    items: [] as ClipboardItem[],
    isLoading: false,
    error: null as string | null,
    autoCopied: null as ClipboardItem | null,
    bound: false,
  }),

  actions: {
    bind() {
      if (this.bound) return;
      this.bound = true;
      realtime.onEvent(RealtimeEvents.clipboardUpdated, (p) => void this.onUpdated(p));
    },

    async loadHistory(limit = 20) {
      this.isLoading = true;
      this.error = null;
      try {
        const res = await http.get<ClipboardItem[]>(ENDPOINTS.clipboardHistory, {
          params: { limit },
        });
        this.items = res.data ?? [];
      } catch {
        this.error = "No se pudo cargar el historial.";
      } finally {
        this.isLoading = false;
      }
    },

    async push(content: string, sourceDeviceId?: string) {
      try {
        const res = await http.post<ClipboardItem>(ENDPOINTS.clipboard, {
          content,
          ...(sourceDeviceId ? { sourceDeviceId } : {}),
        });
        const item = res.data;
        if (!this.items.some((i) => i.id === item.id)) {
          this.items = [item, ...this.items];
        }
      } catch {
        this.error = "No se pudo enviar el texto.";
      }
    },

    async onUpdated(payload: unknown) {
      const itemRaw = (payload as { item?: unknown })?.item;
      if (!itemRaw || typeof itemRaw !== "object") return;
      const item = itemRaw as ClipboardItem;
      if (!this.items.some((i) => i.id === item.id)) {
        this.items = [item, ...this.items];
      }
      await this.autoCopy(item);
    },

    async autoCopy(item: ClipboardItem) {
      const localId = await deviceStorage.readDeviceId();
      if (localId && item.sourceDeviceId === localId) return;

      const ok = await writeClipboard(item.content);
      if (ok) {
        this.autoCopied = item;
      }
    },

    clearAutoCopied() {
      this.autoCopied = null;
    },
  },
});
