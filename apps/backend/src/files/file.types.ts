import { FileStatus } from '../generated/prisma/client.js';

export interface FileResponse {
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

export interface CreateFileResponse {
  file: FileResponse;
  upload: {
    url: string;
    method: 'PUT';
    headers: Record<string, string>;
  };
}

export interface FileDownloadResponse {
  file: FileResponse;
  downloadUrl: string;
  expiresIn: number;
}
