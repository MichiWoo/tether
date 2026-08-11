import { FileRecord, FileStatus, Share } from '../generated/prisma/client.js';
import { FileResponse } from '../files/file.types.js';

export type ShareWithFile = Share & {
  file:
    | (FileRecord & {
        id: string;
        name: string;
        size: number;
        mimeType: string | null;
        checksum: string | null;
        status: FileStatus;
        uploadedAt: Date | null;
        createdAt: Date;
        updatedAt: Date;
      })
    | null;
};

export interface ShareResponse {
  id: string;
  status: Share['status'];
  file: FileResponse | null;
  targetDeviceId: string | null;
  acceptedAt: string | null;
  downloadedAt: string | null;
  expiresAt: string;
  createdAt: string;
}

export interface ShareDetailResponse extends ShareResponse {
  downloadUrl: string | null;
}
