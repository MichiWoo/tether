import { defineStore } from "pinia";
import { ENDPOINTS, fileById, fileComplete, filePreview, http } from "@/core/http";
import { realtime, RealtimeEvents } from "@/core/realtime";
import { invoke } from "@tauri-apps/api/core";
import {
  downloadFile,
  onDownloadProgress,
  onUploadProgress,
  pickDownloadPath,
  pickFiles,
  uploadFile,
} from "@/core/files";
import type { CreateFileResult, FileItem } from "@/core/types";

const MAX_FILE_SIZE = 2147483647; // ~2 GB (Prisma Int 32-bit)

export interface UploadTask {
  id: string;
  name: string;
  progress: number;
  error: string | null;
}

export interface DownloadTask {
  id: string;
  name: string;
  progress: number;
  error: string | null;
}

export const useFilesStore = defineStore("files", {
  state: () => ({
    files: [] as FileItem[],
    uploads: [] as UploadTask[],
    downloads: [] as DownloadTask[],
    isLoading: false,
    error: null as string | null,
    bound: false,
  }),

  actions: {
    bind() {
      if (this.bound) return;
      this.bound = true;
      realtime.onEvent(RealtimeEvents.fileReady, (p) => this.onFileReady(p));
    },

    async load() {
      this.isLoading = true;
      this.error = null;
      try {
        const res = await http.get<FileItem[]>(ENDPOINTS.files, { params: { limit: 50 } });
        this.files = res.data ?? [];
      } catch {
        this.error = "No se pudieron cargar los archivos.";
      } finally {
        this.isLoading = false;
      }
    },

    async pickAndUpload() {
      const picked = await pickFiles();
      if (picked.length === 0) return;
      for (const file of picked) {
        await this.upload(file.name, file.path, file.size);
      }
    },

    // Sube un archivo local por ruta determinando su tamaño (drag & drop).
    async uploadPath(path: string) {
      const name = path.split("/").pop() ?? "archivo";
      let size = 0;
      try {
        size = await invoke<number>("file_size", { path });
      } catch {
        size = 0;
      }
      return this.upload(name, path, size);
    },

    async upload(name: string, path: string, size: number) {
      if (size > MAX_FILE_SIZE) {
        this.upsertUpload({ id: path, name, progress: 0, error: "Máximo permitido: 2 GB" });
        return;
      }

      const id = path;
      this.upsertUpload({ id, name, progress: 0, error: null });

      let uploadUrl = "";
      let contentType = "application/octet-stream";
      let fileId = "";
      try {
        const created = await http.post<CreateFileResult>(ENDPOINTS.files, {
          name,
          size,
          mimeType: mimeFromName(name),
        });
        uploadUrl = created.data.upload.url;
        contentType = created.data.upload.headers["Content-Type"] ?? "application/octet-stream";
        fileId = created.data.file.id;
      } catch {
        this.updateUpload(id, { error: "No se pudo registrar el archivo." });
        return;
      }

      // Progress del PUT directo a S3 vía el backend Rust.
      const offProgress = await onUploadProgress((p) => {
        if (p.id === id && p.total > 0) {
          this.updateUpload(id, { progress: p.sent / p.total });
        }
      });

      try {
        await uploadFile(id, path, uploadUrl, contentType);
        const completed = await http.post<FileItem>(fileComplete(fileId));
        this.upsertFile(completed.data);
        this.dismissUpload(id);
      } catch (e) {
        this.updateUpload(id, { error: uploadError(e) });
      } finally {
        offProgress();
      }
    },

    async getDownloadUrl(id: string): Promise<string> {
      const res = await http.get<{ downloadUrl: string }>(fileById(id));
      return res.data.downloadUrl;
    },

    async getPreviewUrl(id: string): Promise<string> {
      const res = await http.get<{ downloadUrl: string }>(filePreview(id));
      return res.data.downloadUrl;
    },

    async delete(id: string) {
      await http.delete(fileById(id));
      this.files = this.files.filter((f) => f.id !== id);
    },

    // Descarga un archivo (guardar como), con barra de progreso.
    async download(file: FileItem): Promise<boolean> {
      try {
        const url = await this.getDownloadUrl(file.id);
        const savePath = await pickDownloadPath(file.name);
        if (!savePath) return false;

        const id = `${file.id}-${Date.now()}`;
        this.upsertDownload({ id, name: file.name, progress: 0, error: null });

        const offProgress = await onDownloadProgress((p) => {
          if (p.id === id && p.total > 0) {
            this.updateDownload(id, { progress: p.received / p.total });
          }
        });

        try {
          await downloadFile(id, url, savePath);
          this.dismissDownload(id);
          return true;
        } catch (e) {
          this.updateDownload(id, { error: downloadError(e) });
          return false;
        } finally {
          offProgress();
        }
      } catch {
        this.upsertDownload({
          id: file.id,
          name: file.name,
          progress: 0,
          error: "No se pudo preparar la descarga.",
        });
        return false;
      }
    },

    onFileReady(payload: unknown) {
      const fileRaw = (payload as { file?: unknown })?.file;
      if (!fileRaw || typeof fileRaw !== "object") return;
      this.upsertFile(fileRaw as FileItem);
    },

    upsertFile(file: FileItem) {
      const index = this.files.findIndex((f) => f.id === file.id);
      if (index >= 0) this.files[index] = file;
      else this.files = [file, ...this.files];
    },

    upsertUpload(task: UploadTask) {
      const index = this.uploads.findIndex((t) => t.id === task.id);
      if (index >= 0) this.uploads[index] = task;
      else this.uploads = [...this.uploads, task];
    },

    updateUpload(id: string, patch: Partial<UploadTask>) {
      const index = this.uploads.findIndex((t) => t.id === id);
      if (index >= 0) this.uploads[index] = { ...this.uploads[index], ...patch };
    },

    dismissUpload(id: string) {
      this.uploads = this.uploads.filter((t) => t.id !== id);
    },

    upsertDownload(task: DownloadTask) {
      const index = this.downloads.findIndex((t) => t.id === task.id);
      if (index >= 0) this.downloads[index] = task;
      else this.downloads = [...this.downloads, task];
    },

    updateDownload(id: string, patch: Partial<DownloadTask>) {
      const index = this.downloads.findIndex((t) => t.id === id);
      if (index >= 0) this.downloads[index] = { ...this.downloads[index], ...patch };
    },

    dismissDownload(id: string) {
      this.downloads = this.downloads.filter((t) => t.id !== id);
    },
  },
});

function mimeFromName(name: string): string {
  const ext = name.split(".").pop()?.toLowerCase() ?? "";
  const map: Record<string, string> = {
    png: "image/png",
    jpg: "image/jpeg",
    jpeg: "image/jpeg",
    gif: "image/gif",
    webp: "image/webp",
    svg: "image/svg+xml",
    mp4: "video/mp4",
    mov: "video/quicktime",
    mp3: "audio/mpeg",
    wav: "audio/wav",
    pdf: "application/pdf",
    json: "application/json",
    txt: "text/plain",
    md: "text/markdown",
    csv: "text/csv",
    zip: "application/zip",
    tar: "application/x-tar",
    gz: "application/gzip",
  };
  return map[ext] ?? "application/octet-stream";
}

function uploadError(e: unknown): string {
  if (typeof e === "string") return e;
  return "No se pudo subir el archivo.";
}

function downloadError(e: unknown): string {
  if (typeof e === "string") return e;
  return "No se pudo descargar el archivo.";
}
