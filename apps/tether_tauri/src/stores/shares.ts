import { defineStore } from "pinia";
import {
  ENDPOINTS,
  http,
  shareAccept,
  shareById,
  shareCancel,
  shareDownloaded,
} from "@/core/http";
import { realtime, RealtimeEvents } from "@/core/realtime";
import { deviceStorage } from "@/core/storage";
import type { Share, ShareStatus } from "@/core/types";

export const useSharesStore = defineStore("shares", {
  state: () => ({
    shares: [] as Share[],
    isLoading: false,
    error: null as string | null,
    bound: false,
  }),

  actions: {
    bind() {
      if (this.bound) return;
      this.bound = true;
      realtime.onEvent(RealtimeEvents.shareCreated, (p) => this.onShareEvent(p));
      realtime.onEvent(RealtimeEvents.shareAccepted, (p) => this.onShareEvent(p));
      realtime.onEvent(RealtimeEvents.shareDownloaded, (p) => this.onShareEvent(p));
      realtime.onEvent(RealtimeEvents.shareExpired, (p) => this.onExpired(p));
    },

    async load() {
      this.isLoading = true;
      this.error = null;
      try {
        const res = await http.get<Share[]>(ENDPOINTS.shares);
        this.shares = res.data ?? [];
      } catch {
        this.error = "No se pudieron cargar los shares.";
      } finally {
        this.isLoading = false;
      }
    },

    async create(fileId: string, targetDeviceId?: string) {
      const senderDeviceId = (await deviceStorage.readDeviceId()) ?? undefined;
      const res = await http.post<Share>(ENDPOINTS.shares, {
        fileId,
        ...(targetDeviceId ? { targetDeviceId } : {}),
        ...(senderDeviceId ? { senderDeviceId } : {}),
      });
      this.upsert(res.data);
    },

    async accept(id: string) {
      const res = await http.post<Share>(shareAccept(id));
      this.replace(res.data);
      return res.data;
    },

    async markDownloaded(id: string) {
      const res = await http.post<Share>(shareDownloaded(id));
      this.replace(res.data);
      return res.data;
    },

    async cancel(id: string) {
      const res = await http.post<Share>(shareCancel(id));
      this.replace(res.data);
      return res.data;
    },

    async getDownloadUrl(id: string): Promise<string | null> {
      const res = await http.get<{ downloadUrl: string | null }>(shareById(id));
      return res.data.downloadUrl ?? null;
    },

    onShareEvent(payload: unknown) {
      const shareRaw = (payload as { share?: unknown })?.share;
      if (!shareRaw || typeof shareRaw !== "object") return;
      this.upsert(shareRaw as Share);
    },

    onExpired(payload: unknown) {
      const id = (payload as { shareId?: unknown })?.shareId;
      if (typeof id !== "string") return;
      const share = this.shares.find((s) => s.id === id);
      if (share) share.status = "EXPIRED";
    },

    upsert(share: Share) {
      const index = this.shares.findIndex((s) => s.id === share.id);
      if (index >= 0) this.shares[index] = { ...this.shares[index], ...share };
      else this.shares = [share, ...this.shares];
    },

    replace(share: Share) {
      const index = this.shares.findIndex((s) => s.id === share.id);
      if (index >= 0) this.shares[index] = share;
    },
  },
});

export type { ShareStatus };
