import type { DevicePlatform } from '../generated/prisma/client.js';

export class DeviceResponse {
  id: string;
  name: string;
  platform: DevicePlatform;
  isOnline: boolean;
  lastSeenAt: string | null;
  createdAt: string;
  updatedAt: string;
}
