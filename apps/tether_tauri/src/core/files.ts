import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

export interface PickedFile {
  name: string;
  path: string;
  size: number;
}

export function pickFiles(): Promise<PickedFile[]> {
  return invoke<PickedFile[]>("pick_files");
}

export function pickDownloadPath(suggestedName: string): Promise<string | null> {
  return invoke<string | null>("pick_download_path", { suggestedName });
}

export function uploadFile(
  id: string,
  path: string,
  url: string,
  contentType: string,
): Promise<void> {
  return invoke("upload_file", { id, path, url, contentType });
}

export function downloadFile(id: string, url: string, savePath: string): Promise<void> {
  return invoke("download_file", { id, url, savePath });
}

export interface TransferProgress {
  id: string;
  sent: number;
  received: number;
  total: number;
}

// Suscribe a los eventos de progreso emitidos por el backend Rust.
export function onUploadProgress(handler: (p: TransferProgress) => void): Promise<() => void> {
  return listen<TransferProgress>("upload-progress", (event) => handler(event.payload));
}

export function onDownloadProgress(handler: (p: TransferProgress) => void): Promise<() => void> {
  return listen<TransferProgress>("download-progress", (event) => handler(event.payload));
}
