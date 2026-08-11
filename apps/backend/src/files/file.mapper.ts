import { FileStatus } from '../generated/prisma/client.js';
import type { FileResponse } from './file.types.js';

export interface FileLike {
  id: string;
  name: string;
  size: number;
  mimeType: string | null;
  checksum: string | null;
  status: FileStatus;
  uploadedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export function toFileResponse(file: FileLike): FileResponse {
  return {
    id: file.id,
    name: file.name,
    size: file.size,
    mimeType: file.mimeType,
    checksum: file.checksum,
    status: file.status,
    uploadedAt: file.uploadedAt?.toISOString() ?? null,
    createdAt: file.createdAt.toISOString(),
    updatedAt: file.updatedAt.toISOString(),
  };
}

export function objectKey(userId: string, fileId: string): string {
  return `users/${userId}/${fileId}`;
}
