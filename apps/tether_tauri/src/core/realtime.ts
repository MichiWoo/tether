import { io, Socket } from "socket.io-client";
import { ref, type Ref } from "vue";
import { AppConfig } from "./config";

export const RealtimeEvents = {
  deviceOnline: "device.online",
  deviceOffline: "device.offline",
  clipboardUpdated: "clipboard.updated",
  fileReady: "file.ready",
  shareCreated: "share.created",
  shareAccepted: "share.accepted",
  shareDownloaded: "share.downloaded",
  shareExpired: "share.expired",
  identify: "device:identify",
} as const;

export type RealtimeStatus = "disconnected" | "connecting" | "connected";

export interface RealtimeService {
  readonly status: Ref<RealtimeStatus>;
  connect(token: string): void;
  identify(deviceId: string): void;
  disconnect(): void;
  onEvent(event: string, handler: (payload: unknown) => void): () => void;
}

export function createRealtimeService(): RealtimeService {
  let socket: Socket | null = null;
  let deviceId: string | null = null;
  const status = ref<RealtimeStatus>("disconnected");

  function connect(token: string): void {
    disconnect();
    status.value = "connecting";

    socket = io(AppConfig.apiBaseUrl, {
      path: AppConfig.realtimePath,
      transports: ["websocket", "polling"],
      auth: { token },
      autoConnect: true,
      reconnection: true,
      reconnectionDelay: 2000,
      reconnectionAttempts: 60,
    });

    socket.on("connect", () => {
      status.value = "connected";
      if (deviceId) {
        socket?.emit(RealtimeEvents.identify, { deviceId });
      }
    });
    socket.on("disconnect", () => {
      status.value = "disconnected";
    });
    socket.on("connect_error", () => {
      status.value = "disconnected";
    });
  }

  function identify(id: string): void {
    deviceId = id;
    socket?.emit(RealtimeEvents.identify, { deviceId: id });
  }

  function disconnect(): void {
    socket?.disconnect();
    socket = null;
    deviceId = null;
    status.value = "disconnected";
  }

  function onEvent(event: string, handler: (payload: unknown) => void): () => void {
    const listener = (data: unknown) => handler(data);
    socket?.on(event, listener);
    return () => {
      socket?.off(event, listener);
    };
  }

  return { status, connect, identify, disconnect, onEvent };
}
