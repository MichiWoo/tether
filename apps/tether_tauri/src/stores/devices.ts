import { defineStore } from "pinia";
import { deviceById, ENDPOINTS, http } from "@/core/http";
import { realtime, RealtimeEvents } from "@/core/realtime";
import { deviceStorage } from "@/core/storage";
import type { Device } from "@/core/types";

export const useDevicesStore = defineStore("devices", {
  state: () => ({
    devices: [] as Device[],
    localDeviceId: null as string | null,
    error: null as string | null,
    isLoading: false,
    bound: false,
  }),

  actions: {
    bind() {
      if (this.bound) return;
      this.bound = true;
      realtime.onEvent(RealtimeEvents.deviceOnline, (p) => this.applyStatus(p, true));
      realtime.onEvent(RealtimeEvents.deviceOffline, (p) => this.applyStatus(p, false));
    },

    async refreshLocalId() {
      this.localDeviceId = await deviceStorage.readDeviceId();
    },

    applyStatus(payload: unknown, online: boolean) {
      const id = (payload as { deviceId?: unknown })?.deviceId;
      if (typeof id !== "string") return;
      const device = this.devices.find((d) => d.id === id);
      if (!device) return;
      device.isOnline = online;
      if (online) device.lastSeenAt = new Date().toISOString();
    },

    async load() {
      this.isLoading = true;
      this.error = null;
      try {
        const res = await http.get<Device[]>(ENDPOINTS.devices);
        this.devices = res.data ?? [];
      } catch {
        this.error = "No se pudieron cargar los dispositivos.";
      } finally {
        this.isLoading = false;
        await this.refreshLocalId();
      }
    },

    async getLocalDeviceId(): Promise<string | null> {
      return deviceStorage.readDeviceId();
    },

    async ensureCurrentDevice(name: string, platformWire: string): Promise<string> {
      const localId = await deviceStorage.readDeviceId();
      if (localId) {
        this.localDeviceId = localId;
        realtime.identify(localId);
        return localId;
      }
      const res = await http.post<Device>(ENDPOINTS.devices, { name, platform: platformWire });
      const device = res.data;
      await deviceStorage.saveDeviceId(device.id);
      this.localDeviceId = device.id;
      realtime.identify(device.id);
      this.devices = [device, ...this.devices];
      return device.id;
    },

    async register(name: string, platformWire: string) {
      const res = await http.post<Device>(ENDPOINTS.devices, { name, platform: platformWire });
      this.devices = [res.data, ...this.devices];
    },

    async rename(id: string, name: string) {
      const res = await http.patch<Device>(deviceById(id), { name });
      const index = this.devices.findIndex((d) => d.id === id);
      if (index >= 0) this.devices[index] = res.data;
    },

    async remove(id: string) {
      await http.delete(deviceById(id));
      this.devices = this.devices.filter((d) => d.id !== id);
    },
  },
});
