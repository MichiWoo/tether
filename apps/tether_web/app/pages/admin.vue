<script setup lang="ts">
import type { AdminPlansResponse, PlanName } from '~/utils/admin'
import { PLAN_LABELS } from '~/utils/admin'
import AdminMetrics from '~/components/admin/AdminMetrics.vue'
import AdminPlans from '~/components/admin/AdminPlans.vue'
import AdminUsers from '~/components/admin/AdminUsers.vue'
import Mark from '~/components/Mark.vue'

useHead({
  title: 'Tether · Panel de administración',
  meta: [{ name: 'robots', content: 'noindex, nofollow' }],
})

definePageMeta({ layout: false })

const { authed, login, restore, logout, api } = useAdminAuth()

// — Login —
const keyInput = ref('')
const loginFlash = ref<{ msg: string, state: 'ok' | 'error' } | null>(null)
const loggingIn = ref(false)

async function onLogin() {
  const value = keyInput.value.trim()
  loggingIn.value = true
  loginFlash.value = null
  try {
    const ok = await login(value)
    if (!ok) {
      loginFlash.value = { msg: 'Key inválida.', state: 'error' }
    } else {
      refreshSessionChip()
      void loadPlans()
    }
  } catch {
    loginFlash.value = { msg: 'No se pudo conectar con el backend.', state: 'error' }
  } finally {
    loggingIn.value = false
  }
}

function onLogout() {
  logout()
  keyInput.value = ''
  loginFlash.value = null
  activeTab.value = 'plans'
}

// — Tabs —
const TABS = [
  { id: 'plans', label: 'Planes', icon: 'i-lucide-layers' },
  { id: 'users', label: 'Usuarios', icon: 'i-lucide-users' },
  { id: 'metrics', label: 'Métricas', icon: 'i-lucide-chart-column' },
] as const
type TabId = (typeof TABS)[number]['id']

const activeTab = ref<TabId>('plans')
const sessionChip = ref('')
const flash = ref<{ msg: string, state: 'ok' | 'error' } | null>(null)

const usersRef = useTemplateRef<InstanceType<typeof AdminUsers>>('usersRef')

// — Datos de planes (fuente para el form y para validar la sesión) —
const plans = ref<AdminPlansResponse>([])

async function loadPlans() {
  try {
    plans.value = await api<AdminPlansResponse>('/admin/plans')
  } catch {
    // Sin conexión: el panel de planes mostrará su propio error de red al guardar.
  }
}

watch(activeTab, () => {
  flash.value = null
})

function refreshSessionChip() {
  const now = new Date()
  sessionChip.value = `sesión · ${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
}

function reloadTab() {
  flash.value = null
  if (activeTab.value === 'plans') void loadPlans()
  if (activeTab.value === 'users') usersRef.value?.reload()
  if (activeTab.value === 'metrics') {
    // Remonta el panel de métricas: cambia la key para forzar remount.
    metricsKey.value++
  }
}

const metricsKey = ref(0)

function onUserChanged(email: string, plan: PlanName) {
  flash.value = { msg: `Plan de ${email} → ${PLAN_LABELS[plan]}.`, state: 'ok' }
}

function onPlanSaved() {
  void loadPlans()
}

// — Auto-entry si hay key viva en session —
onMounted(async () => {
  await restore()
  if (authed.value) {
    refreshSessionChip()
    void loadPlans()
  }
})
</script>

<template>
  <div class="admin-shell">
    <!-- Sidebar -->
    <aside v-if="authed" class="admin-side" aria-label="Navegación del panel">
      <div class="side-brand">
        <Mark :size="24" />
        <span class="side-brand__text">
          <span class="side-brand__name">Tether</span>
          <span class="side-brand__sub">Panel de administración</span>
        </span>
      </div>
      <nav class="side-nav" aria-label="Secciones del panel">
        <UButton
          v-for="tab in TABS"
          :key="tab.id"
          :icon="tab.icon"
          :label="tab.label"
          block
          color="neutral"
          :variant="activeTab === tab.id ? 'solid' : 'ghost'"
          class="side-nav__btn"
          :aria-current="activeTab === tab.id ? 'page' : undefined"
          @click="activeTab = tab.id"
        />
      </nav>
      <div class="side-footer">
        <span class="side-meta">{{ sessionChip }}</span>
        <UButton
          block
          color="neutral"
          variant="outline"
          size="sm"
          icon="i-lucide-log-out"
          label="Cerrar sesión"
          @click="onLogout"
        />
      </div>
    </aside>

    <!-- Columna principal -->
    <div class="admin-col">
      <!-- Login -->
      <section v-if="!authed" class="login" aria-label="Acceso">
        <UCard class="login-card">
          <template #header>
            <div class="login-head">
              <Mark :size="22" />
              <span>Acceso del operador</span>
            </div>
          </template>
          <form class="login-form" @submit.prevent="onLogin">
            <UFormField label="Key del panel (X-Plan-Admin-Key)" name="key">
              <UInput
                id="keyInput"
                v-model="keyInput"
                type="password"
                autocomplete="off"
                required
                size="lg"
                icon="i-lucide-key-round"
                placeholder="Introduce la key"
                class="w-full"
              />
            </UFormField>
            <UAlert
              v-if="loginFlash"
              :color="loginFlash.state === 'ok' ? 'success' : 'error'"
              variant="subtle"
              :icon="loginFlash.state === 'ok' ? 'i-lucide-check' : 'i-lucide-triangle-alert'"
              :title="loginFlash.msg"
            />
            <UButton
              type="submit"
              block
              size="lg"
              color="neutral"
              icon="i-lucide-log-in"
              label="Entrar"
              :loading="loggingIn"
            />
          </form>
        </UCard>
      </section>

      <template v-else>
        <!-- Topbar -->
        <header class="admin-top">
          <span class="admin-title">{{ TABS.find(t => t.id === activeTab)?.label }}</span>
          <div class="admin-actions">
            <UBadge color="neutral" variant="subtle" icon="i-lucide-clock">{{ sessionChip }}</UBadge>
            <UButton
              color="neutral"
              variant="outline"
              size="sm"
              icon="i-lucide-refresh-cw"
              label="Recargar"
              @click="reloadTab"
            />
          </div>
        </header>

        <main class="admin-main">
          <UAlert
            v-if="flash"
            :color="flash.state === 'ok' ? 'success' : 'error'"
            variant="subtle"
            :icon="flash.state === 'ok' ? 'i-lucide-check' : 'i-lucide-triangle-alert'"
            :title="flash.msg"
          />

          <AdminPlans v-show="activeTab === 'plans'" :plans="plans" @saved="onPlanSaved" />
          <AdminUsers v-show="activeTab === 'users'" ref="usersRef" @changed="onUserChanged" />
          <AdminMetrics v-if="activeTab === 'metrics'" :key="metricsKey" />
        </main>
      </template>
    </div>
  </div>
</template>

<style scoped>
/* Panel de administración: look estándar de dashboard sobre tokens de Nuxt UI
   (independiente del tema one-bit de la landing). */
.admin-shell {
  display: flex;
  min-height: 100vh;
  background: var(--ui-bg);
  color: var(--ui-text);
  font-family: var(--font-body);
}

/* ---------- Sidebar ---------- */
.admin-side {
  flex: 0 0 240px;
  display: flex;
  flex-direction: column;
  border-right: 1px solid var(--ui-border);
  background: var(--ui-bg-elevated);
}
.side-brand {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 16px;
  border-bottom: 1px solid var(--ui-border);
  color: var(--ui-text-highlighted);
}
.side-brand__text {
  display: flex;
  flex-direction: column;
  gap: 1px;
}
.side-brand__name {
  font-weight: 700;
  font-size: 14px;
}
.side-brand__sub {
  font-size: 11px;
  color: var(--ui-text-muted);
}
.side-nav {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: 4px;
  padding: 12px 10px;
}
.side-nav__btn {
  justify-content: flex-start;
}
.side-footer {
  display: flex;
  flex-direction: column;
  gap: 10px;
  border-top: 1px solid var(--ui-border);
  padding: 12px;
}
.side-meta {
  font-size: 11px;
  color: var(--ui-text-muted);
}

/* ---------- Columna principal ---------- */
.admin-col {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-width: 0;
}
.admin-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-1);
  border-bottom: 1px solid var(--ui-border);
  padding: 12px var(--space-2);
  background: var(--ui-bg-elevated);
}
.admin-title {
  font-weight: 700;
  font-size: 16px;
  color: var(--ui-text-highlighted);
}
.admin-actions {
  display: flex;
  align-items: center;
  gap: 10px;
}
.admin-main {
  display: flex;
  flex: 1;
  flex-direction: column;
  gap: var(--space-2);
  width: 100%;
  max-width: var(--content-max);
  margin-inline: auto;
  padding: var(--space-2);
}

/* Login */
.login {
  flex: 1;
  display: grid;
  place-items: center;
  padding: var(--space-3) var(--space-2);
}
.login-card {
  width: min(420px, 94vw);
}
.login-head {
  display: flex;
  align-items: center;
  gap: 10px;
  font-weight: 700;
  color: var(--ui-text-highlighted);
}
.login-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}

@media (max-width: 900px) {
  .admin-shell {
    flex-direction: column;
  }
  .admin-side {
    flex: none;
    border-right: 0;
    border-bottom: 1px solid var(--ui-border);
  }
  .side-nav {
    flex-direction: row;
    overflow-x: auto;
    padding: 8px 10px;
  }
  .side-nav__btn {
    width: auto;
    flex: none;
  }
  .side-brand__sub {
    display: none;
  }
  .admin-main {
    padding: var(--space-1);
  }
}
</style>
