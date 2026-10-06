<script setup lang="ts">
import type { AdminMetricsResponse, PlanName } from '~/utils/admin'
import { DonutType } from 'nuxt-charts/enums'
import { bytes, GB, MB, PLAN_LABELS } from '~/utils/admin'

const { api } = useAdminAuth()

const metrics = ref<AdminMetricsResponse | null>(null)
const loading = ref(true)
const error = ref<string | null>(null)

async function load() {
  loading.value = true
  error.value = null
  try {
    metrics.value = await api<AdminMetricsResponse>('/admin/metrics')
  } catch {
    error.value = 'No se pudieron cargar las métricas.'
  } finally {
    loading.value = false
  }
}

onMounted(load)

// — Datos para gráficas (one-bit: tinta sobre papel, gris dither para lo inactivo) —
const INK = '#f8f8f2'
const DIM = '#8b9cc9'

// BarChart (vccs): `categories` indexa por la clave de la serie (yAxis),
// no por el label de cada punto. El eje X usa la prop `plan` de cada fila.
// Con todo a 0 el dominio se degenera (barras idémnicas): no dibujar.
const usersChart = computed(() => {
  const m = metrics.value
  if (!m || !m.usersByPlan.some(r => (r.count ?? 0) > 0)) return null
  const data = m.usersByPlan.map(r => ({ plan: PLAN_LABELS[r.plan as PlanName] ?? r.plan, usuarios: r.count ?? 0 }))
  const categories = {
    usuarios: { name: 'Usuarios', color: INK },
  }
  return { data, categories }
})

const storageChart = computed(() => {
  const m = metrics.value
  if (!m || !m.storageByPlan.some(r => (r.bytes ?? 0) > MB)) return null
  const data = m.storageByPlan.map(r => ({ plan: PLAN_LABELS[r.plan as PlanName] ?? r.plan, gb: (r.bytes ?? 0) / GB }))
  const categories = {
    gb: { name: 'Storage (GB)', color: INK },
  }
  return { data, categories }
})

const transferChart = computed(() => {
  const m = metrics.value
  if (!m || !m.transferByPlan.some(r => (r.bytes ?? 0) > MB)) return null
  const data = m.transferByPlan.map(r => ({ plan: PLAN_LABELS[r.plan as PlanName] ?? r.plan, gb: (r.bytes ?? 0) / GB }))
  const categories = {
    gb: { name: 'Traspaso (GB)', color: INK },
  }
  return { data, categories }
})

const sharesChart = computed(() => {
  const m = metrics.value
  if (!m) return null
  return {
    data: [m.sharesActive, m.sharesExpired],
    categories: {
      'Activos': { name: 'Activos', color: INK },
      'Expirados': { name: 'Expirados', color: DIM },
    },
  }
})

function statBar(pct: number): number {
  return Math.min(100, Math.max(2, pct))
}
</script>

<template>
  <div class="panel-list">
    <UAlert
      v-if="error"
      color="error"
      variant="subtle"
      icon="i-lucide-triangle-alert"
      :title="error"
    />

    <UCard v-if="loading">
      <div class="skeleton">
        <i v-for="w in ['90%', '70%', '82%', '55%', '64%']" :key="w" :style="{ width: w }" />
      </div>
    </UCard>

    <template v-else-if="metrics">
      <!-- Usuarios por plan -->
      <UCard>
        <template #header>
          <div class="card-head">
            <UIcon name="i-lucide-users" class="card-head__icon" />
            <span class="card-head__title">Usuarios por plan</span>
            <UBadge color="neutral" variant="subtle" class="card-head__badge">
              {{ metrics.usersByPlan.reduce((a, r) => a + (r.count ?? 0), 0) }} total
            </UBadge>
          </div>
        </template>
        <div v-if="usersChart" class="chart-box">
          <BarChart
            :data="usersChart.data"
            :categories="usersChart.categories"
            :height="220"
            x-axis="plan"
            :y-axis='["usuarios"]'
            :radius="0"
            :hide-legend="true"
            :y-grid-line="true"
            variant="hatched"
          />
        </div>
        <p v-else class="plan-note">Sin datos todavía.</p>
        <div class="metrics-row">
          <div v-for="r in metrics.usersByPlan" :key="r.plan" class="stat">
            <b>{{ r.count ?? 0 }}</b>
            <span>{{ PLAN_LABELS[r.plan as PlanName] ?? r.plan }}</span>
          </div>
        </div>
      </UCard>

      <!-- Storage por plan -->
      <UCard>
        <template #header>
          <div class="card-head">
            <UIcon name="i-lucide-hard-drive" class="card-head__icon" />
            <span class="card-head__title">Storage usado</span>
          </div>
        </template>
        <div v-if="storageChart" class="chart-box">
          <BarChart
            :data="storageChart.data"
            :categories="storageChart.categories"
            :height="220"
            x-axis="plan"
            :y-axis='["gb"]'
            :radius="0"
            :hide-legend="true"
            :y-grid-line="true"
            :y-formatter="(t: number) => `${t >= 100 ? Math.round(t) : t.toFixed(1)} GB`"
            variant="hatched"
          />
        </div>
        <p v-else class="plan-note">Sin datos todavía.</p>
        <div class="metrics-row">
          <div v-for="r in metrics.storageByPlan" :key="r.plan" class="stat">
            <b>{{ bytes(r.bytes ?? 0) }}</b>
            <span>{{ PLAN_LABELS[r.plan as PlanName] ?? r.plan }} · storage usado</span>
            <span class="bar"><i :style="{ width: `${statBar(((r.bytes ?? 0) / (500 * GB)) * 100)}%` }" /></span>
          </div>
        </div>
      </UCard>

      <!-- Traspaso del mes -->
      <UCard>
        <template #header>
          <div class="card-head">
            <UIcon name="i-lucide-arrow-right-left" class="card-head__icon" />
            <span class="card-head__title">Traspaso del mes</span>
          </div>
        </template>
        <div v-if="transferChart" class="chart-box">
          <BarChart
            :data="transferChart.data"
            :categories="transferChart.categories"
            :height="220"
            x-axis="plan"
            :y-axis='["gb"]'
            :radius="0"
            :hide-legend="true"
            :y-grid-line="true"
            :y-formatter="(t: number) => `${t >= 100 ? Math.round(t) : t.toFixed(1)} GB`"
            variant="hatched"
          />
        </div>
        <p v-else class="plan-note">Sin datos todavía.</p>
        <div class="metrics-row">
          <div v-for="r in metrics.transferByPlan" :key="r.plan" class="stat">
            <b>{{ bytes(r.bytes ?? 0) }}</b>
            <span>{{ PLAN_LABELS[r.plan as PlanName] ?? r.plan }} · traspaso del mes</span>
            <span class="bar"><i :style="{ width: `${statBar(((r.bytes ?? 0) / (250 * GB)) * 100)}%` }" /></span>
          </div>
        </div>
      </UCard>

      <!-- Estado del sistema -->
      <UCard>
        <template #header>
          <div class="card-head">
            <UIcon name="i-lucide-activity" class="card-head__icon" />
            <span class="card-head__title">Estado del sistema</span>
          </div>
        </template>
        <div class="metrics-grid">
          <div class="metrics-row">
            <div class="stat">
              <b>{{ metrics.activeDevices }}</b>
              <span>dispositivos activos (2 min)</span>
            </div>
            <div class="stat">
              <b>{{ metrics.sharesActive }}</b>
              <span>shares activos</span>
            </div>
            <div class="stat">
              <b>{{ metrics.sharesExpired }}</b>
              <span>shares expirados</span>
            </div>
          </div>
          <div v-if="sharesChart" class="chart-box donut-box">
            <DonutChart
              :data="sharesChart.data"
              :categories="sharesChart.categories"
              :height="200"
              :radius="4"
              :arc-width="24"
              :pad-angle="0.05"
              :type="DonutType.Full"
              variant="flat"
            />
          </div>
        </div>
      </UCard>

      <p class="plan-note">Ventana de traspaso desde {{ new Date(metrics.monthStart).toLocaleDateString() }}.</p>
    </template>
  </div>
</template>

<style scoped>
.panel-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
.card-head {
  display: flex;
  align-items: center;
  gap: 8px;
  font-weight: 600;
  font-size: 14px;
  color: var(--ui-text-highlighted);
}
.card-head__icon {
  width: 18px;
  height: 18px;
  color: var(--ui-text-muted);
}
.card-head__badge {
  margin-left: auto;
}
.metrics-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr));
  gap: var(--space-1);
  margin-top: var(--space-1);
}
.metrics-grid {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: var(--space-2);
  align-items: center;
}
.stat {
  border: 1px solid var(--ui-border);
  border-radius: var(--ui-radius, 6px);
  background: var(--ui-bg-muted);
  padding: 12px 14px;
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.stat b {
  font-size: 20px;
  font-weight: 700;
  line-height: 1.1;
  color: var(--ui-text-highlighted);
}
.stat span {
  font-size: 11px;
  color: var(--ui-text-muted);
}
.stat .bar {
  margin-top: 4px;
  border-radius: 999px;
  background: var(--ui-bg-accented);
  overflow: hidden;
  height: 8px;
}
.stat .bar i {
  display: block;
  height: 100%;
  background: var(--ui-text);
}
.chart-box {
  border: 1px solid var(--ui-border);
  border-radius: var(--ui-radius, 6px);
  padding: var(--space-1);
}
.donut-box {
  width: 220px;
}
.plan-note {
  font-size: 12px;
  color: var(--ui-text-muted);
}
.skeleton {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
.skeleton i {
  display: block;
  height: 16px;
  border-radius: 4px;
  background: var(--ui-bg-accented);
  opacity: 0.6;
}

@media (max-width: 900px) {
  .metrics-grid {
    grid-template-columns: 1fr;
  }
  .donut-box {
    width: auto;
    justify-self: center;
  }
}
</style>
