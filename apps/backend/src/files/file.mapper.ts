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

const MAX_SEGMENT_LENGTH = 120;

/// Sanitiza el nombre del archivo para usarlo como segmento de key S3:
/// reemplaza separadores de ruta y caracteres de control, recorta espacios y
/// limita la longitud para no exceder el límite de 1024 bytes de S3.
export function sanitizeKeySegment(name: string): string {
  const normalized = name.normalize('NFKC');
  const withoutControl = Array.from(normalized)
    .map((char) => {
      const code = char.codePointAt(0) ?? 0;
      if (char === '/' || char === '\\' || code < 0x20 || code === 0x7f) {
        return '_';
      }
      return char;
    })
    .join('');

  return (
    withoutControl.replace(/\s+/g, ' ').trim().slice(0, MAX_SEGMENT_LENGTH).replace(/\.+$/, '') ||
    'file'
  );
}

export function objectKey(userId: string, fileId: string, name?: string | null): string {
  const base = `users/${userId}/${fileId}`;
  if (!name) {
    return base;
  }
  return `${base}/${sanitizeKeySegment(name)}`;
}
