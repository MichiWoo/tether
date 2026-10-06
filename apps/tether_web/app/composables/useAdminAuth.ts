// Panel admin — auth por key compartida (header x-plan-admin-key) y fetch helper.
// La key vive en sessionStorage y solo viaja por header; nunca se incrusta en HTML.
const KEY_STORE = 'tether-admin-key'

export function useAdminAuth() {
  const config = useRuntimeConfig()
  const apiBase = config.public.apiBase
  const authed = useState('admin-authed', () => false)

  function key(): string {
    return sessionStorage.getItem(KEY_STORE) ?? ''
  }

  async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
    const res = await fetch(`${apiBase}${path}`, {
      ...init,
      headers: {
        'content-type': 'application/json',
        'x-plan-admin-key': key(),
        ...(init.headers ?? {}),
      },
    })
    if (!res.ok) {
      const body = (await res.json().catch(() => null)) as { message?: string } | null
      throw Object.assign(new Error(body?.message ?? `HTTP ${res.status}`), { status: res.status })
    }
    return res.json() as Promise<T>
  }

  async function login(value: string): Promise<boolean> {
    const res = await fetch(`${apiBase}/admin/plans`, { headers: { 'x-plan-admin-key': value } })
    if (!res.ok) return false
    sessionStorage.setItem(KEY_STORE, value)
    authed.value = true
    return true
  }

  async function restore(): Promise<boolean> {
    if (!key()) return false
    try {
      const res = await fetch(`${apiBase}/admin/plans`, { headers: { 'x-plan-admin-key': key() } })
      if (!res.ok) {
        sessionStorage.removeItem(KEY_STORE)
        return false
      }
      authed.value = true
      return true
    } catch {
      return false
    }
  }

  function logout() {
    sessionStorage.removeItem(KEY_STORE)
    authed.value = false
  }

  return { authed, key, api, login, restore, logout }
}
