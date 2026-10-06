<script setup lang="ts">
import type { AdminPlan, PlanLimits, PlanName } from '~/utils/admin'
import { GB, LIMIT_FIELDS, MB, PLAN_LABELS } from '~/utils/admin'

const props = defineProps<{ plans: AdminPlan[] }>()

const emit = defineEmits<{ saved: [plan: PlanName] }>()

const { api } = useAdminAuth()

interface PlanForm {
  // string | number: UInput emite string; `savePlan` normaliza con Number().
  values: Record<string, string | number>
  flash: { msg: string, state: 'ok' | 'error' } | null
  saving: boolean
  updatedAt: string
}

const forms = reactive<Record<string, PlanForm>>({})

// Registra/actualiza los forms cuando llegan (o cambian) los planes.
function syncForms(list: AdminPlan[]) {
  for (const plan of list) {
    const values: Record<string, string | number> = {}
    for (const [name, , unit] of LIMIT_FIELDS) {
      const raw = plan.limits[name]
      values[name] = unit === 'gb' ? raw / GB : unit === 'mb' ? raw / MB : raw
    }
    const planCode = plan.plan as PlanName
    const existing = forms[planCode]
    if (existing) {
      // Preserva lo tecleado si ya hay form; solo refresca updatedAt.
      existing.updatedAt = new Date(plan.updatedAt).toLocaleString()
    } else {
      forms[planCode] = {
        values,
        flash: null,
        saving: false,
        updatedAt: new Date(plan.updatedAt).toLocaleString(),
      }
    }
  }
}

watch(() => props.plans, syncForms, { immediate: true, deep: true })

// No renderizar hasta que haya forms registrados para todos los planes.
const ready = computed(() => props.plans.length > 0 && props.plans.every(p => forms[p.plan]))

async function savePlan(planName: PlanName) {
  const form = forms[planName]
  if (!form) return
  const payload: Record<string, number> = {}
  const bad: string[] = []
  for (const [name, , unit] of LIMIT_FIELDS) {
    const v = Number(form.values[name])
    const unitSize = name === 'maxFileSizeBytes' ? MB : GB
    payload[name] = unit === 'u' ? Math.round(v) : Math.round(v * unitSize)
    if (!Number.isFinite(payload[name]) || payload[name]! < 0) bad.push(name)
  }
  if (bad.length) {
    form.flash = { msg: `Valores inválidos: ${bad.join(', ')}`, state: 'error' }
    return
  }
  form.saving = true
  form.flash = null
  try {
    await api<PlanLimits>(`/admin/plans/${planName}`, { method: 'PUT', body: JSON.stringify(payload) })
    form.flash = { msg: `Plan ${PLAN_LABELS[planName]} actualizado.`, state: 'ok' }
    form.updatedAt = new Date().toLocaleString()
    emit('saved', planName)
  } catch (e) {
    form.flash = { msg: `Error: ${(e as Error).message}`, state: 'error' }
  } finally {
    form.saving = false
  }
}
</script>

<template>
  <div v-if="ready" class="plans">
    <UCard v-for="plan in plans" :key="plan.plan" class="plan-card">
      <template #header>
        <div class="plan-head">
          <span class="plan-head__name">{{ PLAN_LABELS[plan.plan as PlanName] }}</span>
          <UBadge color="neutral" variant="subtle">{{ plan.plan }}</UBadge>
        </div>
      </template>

      <form class="plan-form" @submit.prevent="savePlan(plan.plan as PlanName)">
        <div class="plan-fields">
          <UFormField
            v-for="[name, label] in LIMIT_FIELDS"
            :key="name"
            :label="label"
          >
            <UInput
              v-model="forms[plan.plan as PlanName]!.values[name]"
              type="number"
              step="any"
              min="0"
              color="neutral"
              class="w-full"
            />
          </UFormField>
        </div>

        <p class="plan-updated">Actualizado: {{ forms[plan.plan as PlanName]?.updatedAt }}</p>
        <UAlert
          v-if="forms[plan.plan as PlanName]?.flash"
          :color="forms[plan.plan as PlanName]?.flash?.state === 'ok' ? 'success' : 'error'"
          variant="subtle"
          :icon="forms[plan.plan as PlanName]?.flash?.state === 'ok' ? 'i-lucide-check' : 'i-lucide-triangle-alert'"
          :title="forms[plan.plan as PlanName]?.flash?.msg"
        />
        <UButton
          type="submit"
          block
          color="neutral"
          icon="i-lucide-save"
          label="Guardar cambios"
          :loading="forms[plan.plan as PlanName]?.saving"
        />
      </form>
    </UCard>
  </div>
  <p v-else class="plans-loading">Cargando planes…</p>
</template>

<style scoped>
.plans-loading {
  font-size: 12px;
  color: var(--ui-text-muted);
}
.plans {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: var(--space-2);
  align-items: stretch;
}
.plan-card {
  display: flex;
  flex-direction: column;
}
.plan-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-1);
}
.plan-head__name {
  font-weight: 700;
  font-size: 15px;
  color: var(--ui-text-highlighted);
}
.plan-form {
  display: flex;
  flex-direction: column;
  gap: var(--space-2);
}
.plan-fields {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
.plan-updated {
  font-size: 11px;
  color: var(--ui-text-muted);
}

@media (max-width: 900px) {
  .plans {
    grid-template-columns: 1fr;
  }
}
</style>
