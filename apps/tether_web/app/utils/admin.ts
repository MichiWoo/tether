import type {
  AdminMetricsResponse,
  AdminPlan,
  AdminPlansResponse,
  AdminUser,
  AdminUsersResponse,
  PlanLimits,
  PlanName,
} from '@tether/protocol'

export type {
  AdminMetricsResponse,
  AdminPlan,
  AdminPlansResponse,
  AdminUser,
  AdminUsersResponse,
  PlanLimits,
  PlanName,
}

export const PLAN_LABELS: Record<PlanName, string> = {
  FREE: 'Freemium',
  PRO: 'Pro',
  UNLIMITS: 'Unlimits',
}

export const PLAN_CODES: PlanName[] = ['FREE', 'PRO', 'UNLIMITS']

export const PLAN_SCALE: Record<PlanName, string> = {
  FREE: '25',
  PRO: '50',
  UNLIMITS: '75',
}

export const GB = 1024 ** 3
export const MB = 1024 ** 2

export const LIMIT_FIELDS: Array<[keyof PlanLimits, string, 'gb' | 'mb' | 'u']> = [
  ['maxStorageBytes', 'Espacio (GB)', 'gb'],
  ['maxFileSizeBytes', 'Archivo máximo (MB)', 'mb'],
  ['monthlyTransferBytes', 'Traspaso mensual (GB)', 'gb'],
  ['maxDevices', 'Dispositivos', 'u'],
  ['shareTtlDays', 'TTL shares (días)', 'u'],
  ['clipboardHistoryItems', 'Historial de portapapeles', 'u'],
  ['clipboardRetentionDays', 'Retención de portapapeles (días)', 'u'],
]

export function bytes(n?: number | null): string {
  if (!Number.isFinite(n) || !n) return '—'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  let v = n
  let i = 0
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024
    i += 1
  }
  return `${v >= 100 ? Math.round(v) : v.toFixed(1)} ${units[i]}`
}
