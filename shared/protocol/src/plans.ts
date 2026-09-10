export type PlanName = "FREE" | "PRO" | "UNLIMITS";

export const PLAN_CODES = ["FREE", "PRO", "UNLIMITS"] as const;

export interface PlanLimits {
  maxStorageBytes: number;
  maxFileSizeBytes: number;
  monthlyTransferBytes: number;
  maxDevices: number;
  shareTtlDays: number;
  clipboardHistoryItems: number;
  clipboardRetentionDays: number;
}

export const PLAN_LIMITS: Record<PlanName, PlanLimits> = {
  FREE: {
    maxStorageBytes: 2 * 1024 ** 3,
    maxFileSizeBytes: 100 * 1024 ** 2,
    monthlyTransferBytes: 5 * 1024 ** 3,
    maxDevices: 3,
    shareTtlDays: 7,
    clipboardHistoryItems: 50,
    clipboardRetentionDays: 30,
  },
  PRO: {
    maxStorageBytes: 50 * 1024 ** 3,
    maxFileSizeBytes: 2 * 1024 ** 3,
    monthlyTransferBytes: 50 * 1024 ** 3,
    maxDevices: 10,
    shareTtlDays: 30,
    clipboardHistoryItems: 500,
    clipboardRetentionDays: 365,
  },
  UNLIMITS: {
    maxStorageBytes: 500 * 1024 ** 3,
    maxFileSizeBytes: 5 * 1024 ** 3,
    monthlyTransferBytes: 250 * 1024 ** 3,
    maxDevices: 20,
    shareTtlDays: 90,
    clipboardHistoryItems: 1000,
    clipboardRetentionDays: 730,
  },
} as const;

export type QuotaErrorCode =
  | "QUOTA_STORAGE_EXCEEDED"
  | "QUOTA_FILE_TOO_LARGE"
  | "QUOTA_DEVICE_LIMIT"
  | "QUOTA_TRANSFER_EXCEEDED";

export interface PlanUsageResponse {
  plan: PlanName;
  limits: PlanLimits;
  storageUsedBytes: number;
  transferUsedThisMonthBytes: number;
  devicesUsed: number;
  clipboardItemsUsed: number;
  monthlyTransferWindow: { start: string; end: string };
}
