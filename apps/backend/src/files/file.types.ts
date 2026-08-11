import type { FileStatus } from '../generated/prisma/client.js';

export class FileResponse {
  id: string;
  name: string;
  size: number;
  mimeType: string | null;
  checksum: string | null;
  status: FileStatus;
  uploadedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export class FileUploadInfo {
  url: string;
  method: 'PUT';
  headers: Record<string, string>;
}

export class CreateFileResponse {
  file: FileResponse;
  upload: FileUploadInfo;
}

export class FileDownloadResponse {
  file: FileResponse;
  downloadUrl: string;
  expiresIn: number;
}
