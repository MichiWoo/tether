export class ReleaseResponse {
  id: string;
  version: string;
  channel: string;
  platform: string;
  arch: string;
  filename: string;
  size: number;
  checksum: string;
  signature: string | null;
  notes: string | null;
  isPrimary: boolean;
  publishedAt: string;
  downloadUrl: string;
  expiresIn: number;
}

export interface ReleaseRecordLike {
  id: string;
  version: string;
  channel: string;
  platform: string;
  arch: string;
  filename: string;
  s3Key: string;
  size: number;
  checksum: string;
  signature: string | null;
  notes: string | null;
  isPrimary: boolean;
  publishedAt: Date;
}
