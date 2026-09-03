// Modelos de dominio, reflejo de `apps/backend` (Prisma) y del DTO de la API.

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

export interface User {
  id: string;
  email: string;
  name?: string | null;
}

export interface AuthResult {
  accessToken: string;
  refreshToken: string;
  user: User;
}

export function userDisplayName(user: User): string {
  const n = user.name;
  return n && n.length > 0 ? n : user.email.split("@")[0];
}

export type DevicePlatformWire = "IOS" | "ANDROID" | "WINDOWS" | "LINUX" | "MACOS" | "WEB";

export interface Device {
  id: string;
  name: string;
  platform: DevicePlatformWire;
  isOnline: boolean;
  lastSeenAt?: string | null;
  createdAt: string;
}

export function devicePlatformLabel(platform: string): string {
  switch (platform.toUpperCase()) {
    case "IOS":
      return "iOS";
    case "ANDROID":
      return "Android";
    case "WINDOWS":
      return "Windows";
    case "LINUX":
      return "Linux";
    case "MACOS":
      return "macOS";
    default:
      return "Web";
  }
}

export interface ClipboardItem {
  id: string;
  content: string;
  sourceDeviceId?: string | null;
  sourceDeviceName?: string | null;
  createdAt: string;
}

export type FileStatus = "PENDING" | "UPLOADED";

export interface FileItem {
  id: string;
  name: string;
  size: number;
  mimeType?: string | null;
  status: FileStatus;
  uploadedAt?: string | null;
  createdAt: string;
}

export function isUploaded(file: FileItem): boolean {
  return file.status === "UPLOADED";
}

export function formatSize(size: number): string {
  if (size < 1024) return `${size} B`;
  if (size < 1024 * 1024) return `${(size / 1024).toFixed(1)} KB`;
  if (size < 1024 * 1024 * 1024) return `${(size / (1024 * 1024)).toFixed(1)} MB`;
  return `${(size / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}

export type ShareStatus = "CREATED" | "ACCEPTED" | "DOWNLOADED" | "EXPIRED";

export interface Share {
  id: string;
  status: ShareStatus;
  file?: FileItem | null;
  senderDeviceId?: string | null;
  targetDeviceId?: string | null;
  acceptedAt?: string | null;
  downloadedAt?: string | null;
  expiresAt: string;
  createdAt: string;
}

export function shareStatusLabel(status: ShareStatus): string {
  switch (status) {
    case "CREATED":
      return "Pendiente";
    case "ACCEPTED":
      return "Aceptado";
    case "DOWNLOADED":
      return "Descargado";
    case "EXPIRED":
      return "Expirado";
  }
}

// Respuesta de `GET /stats`.
export interface Stats {
  filesUploaded: number;
  filesTotalSize: number;
  shares: number;
  devices: number;
  clipboardItems: number;
}

// Respuesta de `POST /files`.
export interface CreateFileResult {
  file: FileItem;
  upload: {
    url: string;
    method: "PUT";
    headers: Record<string, string>;
  };
}
