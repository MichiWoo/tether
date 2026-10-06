export interface ReleaseAsset {
  platform: string
  arch?: string
  version: string
  filename?: string
  size?: number
  downloadUrl?: string
  isPrimary?: boolean
}

const PRIMARY_EXT: Record<string, string[]> = {
  macos: ['.dmg'],
  windows: ['.msi', '-setup.exe', '.exe'],
  linux: ['.AppImage', '.deb', '.rpm'],
  android: ['.apk'],
}

const ARCHES: Record<string, string> = {
  x86_64: 'x64',
  aarch64: 'Apple Silicon',
  universal: 'Universal',
}

export function formatBytes(size?: number): string {
  if (!Number.isFinite(size) || !size || size <= 0) return ''
  const units = ['B', 'KB', 'MB', 'GB']
  let v = size
  let u = 0
  while (v >= 1024 && u < units.length - 1) {
    v /= 1024
    u += 1
  }
  return `${v >= 100 ? Math.round(v) : v.toFixed(1)} ${units[u]}`
}

export function pickPrimary(candidates: ReleaseAsset[], platform: string): ReleaseAsset | undefined {
  const flagged = candidates.find(r => r.isPrimary)
  if (flagged) return flagged
  const exts = PRIMARY_EXT[platform] ?? []
  for (const ext of exts) {
    const hit = candidates.find(r =>
      (r.filename ?? '').toLowerCase().endsWith(ext.toLowerCase()),
    )
    if (hit) return hit
  }
  return candidates[0]
}

export function archLabel(arch?: string): string {
  return (arch && ARCHES[arch]) || arch || ''
}
