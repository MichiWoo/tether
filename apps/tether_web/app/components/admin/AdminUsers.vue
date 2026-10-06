<script setup lang="ts">
import type { TableColumn } from '@nuxt/ui'
import type { AdminUser, PlanName } from '~/utils/admin'
import { bytes, PLAN_CODES, PLAN_LABELS } from '~/utils/admin'

const { api } = useAdminAuth()

const emit = defineEmits<{ changed: [email: string, plan: PlanName] }>()

const TAKE = 25

const q = ref('')
const page = ref(1)
const total = ref(0)
const items = ref<AdminUser[]>([])
const loading = ref(false)
const error = ref<string | null>(null)
const pendingPlan = ref<Record<string, PlanName>>({})
const savingId = ref<string | null>(null)

// Opciones para el USelect de plan.
const planItems = PLAN_CODES.map(p => ({ label: PLAN_LABELS[p], value: p }))

// Columnas de la UTable (las celdas con formato se pintan vía slots #<id>-cell).
const columns: TableColumn<AdminUser>[] = [
  { accessorKey: 'email', header: 'Email' },
  { accessorKey: 'name', header: 'Nombre' },
  { accessorKey: 'plan', header: 'Plan' },
  { accessorKey: 'devices', header: 'Disp.' },
  { accessorKey: 'storageBytes', header: 'Storage' },
  { accessorKey: 'transferBytesThisMonth', header: 'Traspaso mes' },
  { accessorKey: 'createdAt', header: 'Alta' },
  { id: 'actions', header: 'Acciones' },
]

async function load() {
  loading.value = true
  error.value = null
  try {
    const data = await api<import('~/utils/admin').AdminUsersResponse>(
      `/admin/users?q=${encodeURIComponent(q.value)}&page=${page.value}&take=${TAKE}`,
    )
    items.value = data.items
    total.value = data.total
    const next: Record<string, PlanName> = {}
    for (const u of data.items) next[u.id] = u.plan
    pendingPlan.value = next
  } catch {
    error.value = 'No se pudieron cargar los usuarios.'
  } finally {
    loading.value = false
  }
}

watch(q, () => {
  page.value = 1
})

const pages = computed(() => Math.max(1, Math.ceil(total.value / TAKE)))

async function setPlan(id: string, email: string) {
  const plan = pendingPlan.value[id]
  if (!plan) return
  savingId.value = id
  try {
    await api(`/admin/users/${id}/plan`, { method: 'PUT', body: JSON.stringify({ plan }) })
    emit('changed', email, plan)
    await load()
  } catch (e) {
    error.value = `No se pudo cambiar el plan: ${(e as Error).message}`
  } finally {
    savingId.value = null
  }
}

onMounted(load)

defineExpose({ reload: load })
</script>

<template>
  <div class="panel-list">
    <div class="users-toolbar">
      <UInput
        v-model="q"
        class="users-search"
        type="search"
        icon="i-lucide-search"
        placeholder="Buscar por email o nombre…"
        aria-label="Buscar usuarios"
        @keyup.enter="page = 1; load()"
      />
      <span class="users-count">{{ total }} usuario(s)</span>
    </div>

    <UAlert
      v-if="error"
      color="error"
      variant="subtle"
      icon="i-lucide-triangle-alert"
      :title="error"
    />

    <UCard :ui="{ body: 'p-0 sm:p-0' }">
      <UTable
        :data="items"
        :columns="columns"
        :loading="loading"
        class="users-table"
      >
        <template #name-cell="{ row }">
          {{ row.original.name ?? '—' }}
        </template>
        <template #plan-cell="{ row }">
          <UBadge
            color="neutral"
            :variant="row.original.plan === 'FREE' ? 'outline' : 'subtle'"
          >
            {{ PLAN_LABELS[row.original.plan as PlanName] ?? row.original.plan }}
          </UBadge>
        </template>
        <template #storageBytes-cell="{ row }">
          {{ bytes(row.original.storageBytes) }}
        </template>
        <template #transferBytesThisMonth-cell="{ row }">
          {{ bytes(row.original.transferBytesThisMonth) }}
        </template>
        <template #createdAt-cell="{ row }">
          {{ new Date(row.original.createdAt).toLocaleDateString() }}
        </template>
        <template #actions-cell="{ row }">
          <div class="cell-actions">
            <USelect
              v-model="pendingPlan[row.original.id]"
              :items="planItems"
              color="neutral"
              class="w-32"
              :aria-label="`Plan de ${row.original.email}`"
            />
            <UButton
              color="neutral"
              variant="outline"
              size="sm"
              icon="i-lucide-check"
              label="Aplicar"
              :loading="savingId === row.original.id"
              :disabled="savingId === row.original.id || pendingPlan[row.original.id] === row.original.plan"
              @click="setPlan(row.original.id, row.original.email)"
            />
          </div>
        </template>
        <template #empty>
          <span class="users-empty">Sin resultados.</span>
        </template>
      </UTable>
    </UCard>

    <div class="users-toolbar">
      <UButton
        color="neutral"
        variant="outline"
        icon="i-lucide-chevron-left"
        label="Anterior"
        :disabled="page <= 1"
        @click="page--; load()"
      />
      <span class="users-count">página {{ page }} / {{ pages }}</span>
      <UButton
        color="neutral"
        variant="outline"
        trailing-icon="i-lucide-chevron-right"
        label="Siguiente"
        :disabled="page * TAKE >= total"
        @click="page++; load()"
      />
    </div>
  </div>
</template>

<style scoped>
.panel-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-1);
}
.users-toolbar {
  display: flex;
  gap: 10px;
  align-items: center;
  flex-wrap: wrap;
}
.users-search {
  max-width: 320px;
}
.users-count {
  font-size: 12px;
  color: var(--ui-text-muted);
}
.cell-actions {
  display: flex;
  gap: 6px;
  align-items: center;
}
.users-empty {
  font-size: 13px;
  color: var(--ui-text-muted);
}
</style>
