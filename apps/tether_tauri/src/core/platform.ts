import { invoke } from "@tauri-apps/api/core";

export type PlatformOs = "macos" | "windows" | "linux" | "ios" | "android" | "web";

interface PlatformInfo {
  os: string;
  isDesktop: boolean;
}

let cached: PlatformInfo | null = null;

/** Detecta el sistema operativo actual (vía el backend Rust). */
export async function platformInfo(): Promise<PlatformInfo> {
  if (!cached) {
    cached = await invoke<PlatformInfo>("platform_info");
  }
  return cached;
}

export function platformOsToWire(os: string): string {
  switch (os) {
    case "macos":
      return "MACOS";
    case "windows":
      return "WINDOWS";
    case "linux":
      return "LINUX";
    case "ios":
      return "IOS";
    case "android":
      return "ANDROID";
    default:
      return "WEB";
  }
}

export function platformOsLabel(os: string): string {
  switch (os) {
    case "macos":
      return "macOS";
    case "windows":
      return "Windows";
    case "linux":
      return "Linux";
    case "ios":
      return "iOS";
    case "android":
      return "Android";
    default:
      return "Web";
  }
}

export function defaultDeviceName(os: string): string {
  switch (os) {
    case "macos":
      return "Mi Mac";
    case "windows":
      return "Mi PC";
    case "linux":
      return "Mi PC";
    case "ios":
      return "Mi iPhone";
    case "android":
      return "Mi Android";
    default:
      return "Este equipo";
  }
}
