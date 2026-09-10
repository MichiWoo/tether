import axios from "axios";

export type QuotaErrorCode =
  | "QUOTA_STORAGE_EXCEEDED"
  | "QUOTA_FILE_TOO_LARGE"
  | "QUOTA_DEVICE_LIMIT"
  | "QUOTA_TRANSFER_EXCEEDED";

const QUOTA_MESSAGES: Record<QuotaErrorCode, string> = {
  QUOTA_FILE_TOO_LARGE: "El archivo excede el máximo de tu plan.",
  QUOTA_STORAGE_EXCEEDED: "Sin espacio disponible en tu plan. Libera archivos o cambia de plan.",
  QUOTA_DEVICE_LIMIT: "Alcanzaste el límite de dispositivos de tu plan.",
  QUOTA_TRANSFER_EXCEEDED: "Alcanzaste la cuota mensual de transferencias de tu plan.",
};

export function quotaCode(error: unknown): QuotaErrorCode | null {
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as { code?: string } | undefined;
    if (data?.code && data.code in QUOTA_MESSAGES) return data.code as QuotaErrorCode;
  }
  return null;
}

export function quotaMessage(error: unknown): string | null {
  const code = quotaCode(error);
  return code ? QUOTA_MESSAGES[code] : null;
}

export function isQuotaError(error: unknown): boolean {
  return quotaCode(error) !== null;
}
