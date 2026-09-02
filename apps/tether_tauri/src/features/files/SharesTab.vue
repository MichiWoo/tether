<script setup lang="ts">
import { computed, ref } from "vue";
import {
  CloudDownload,
  Inbox,
  Share2,
  XCircle,
} from "@lucide/vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import CardTile from "@/components/ui/CardTile.vue";
import UiButton from "@/components/ui/UiButton.vue";
import { showToast } from "@/components/ui/toast";
import { useSharesStore } from "@/stores/shares";
import { useFilesStore } from "@/stores/files";
import { useDevicesStore } from "@/stores/devices";
import { shareStatusLabel, type Share } from "@/core/types";

const shares = useSharesStore();
const files = useFilesStore();
const devices = useDevicesStore();

const filter = ref<"received" | "sent">("received");

const localId = computed(() => devices.localDeviceId);

const received = computed(() => {
  if (!localId.value) return shares.shares;
  return shares.shares.filter((s) => !s.senderDeviceId || s.senderDeviceId !== localId.value);
});

const sent = computed(() => {
  if (!localId.value) return [] as Share[];
  return shares.shares.filter((s) => s.senderDeviceId && s.senderDeviceId === localId.value);
});

const visible = computed(() => (filter.value === "received" ? received.value : sent.value));

function deviceName(id?: string | null): string {
  if (!id) return "Todos los dispositivos";
  return devices.devices.find((d) => d.id === id)?.name ?? "Dispositivo desconocido";
}

async function accept(share: Share) {
  try {
    await shares.accept(share.id);
  } catch {
    showToast("No se pudo aceptar el share.", "error");
  }
}

async function download(share: Share) {
  const name = share.file?.name ?? "archivo";
  try {
    const url = await shares.getDownloadUrl(share.id);
    if (!url) {
      showToast("El share está expirado.", "error");
      return;
    }
    const ok = await files.download({ id: share.file?.id ?? share.id, name, mimeType: share.file?.mimeType ?? null, size: share.file?.size ?? 0, status: "UPLOADED", createdAt: share.createdAt });
    if (ok) {
      await shares.markDownloaded(share.id);
    } else {
      showToast("No se pudo descargar el share.", "error");
    }
  } catch {
    showToast("No se pudo descargar el share.", "error");
  }
}

async function cancel(share: Share) {
  try {
    await shares.cancel(share.id);
  } catch {
    showToast("No se pudo cancelar el share.", "error");
  }
}
</script>

<template>
  <div class="flex min-h-0 flex-1 flex-col overflow-hidden">
    <div class="flex items-center justify-between px-6 pb-3 pt-1">
      <div class="flex rounded-xl bg-bg-2 p-1">
        <button
          class="rounded-lg px-4 py-1.5 text-sm font-medium transition-colors"
          :class="filter === 'received' ? 'bg-surface-2 text-fg' : 'text-muted hover:text-fg'"
          @click="filter = 'received'"
        >
          Recibidos
        </button>
        <button
          class="rounded-lg px-4 py-1.5 text-sm font-medium transition-colors"
          :class="filter === 'sent' ? 'bg-surface-2 text-fg' : 'text-muted hover:text-fg'"
          @click="filter = 'sent'"
        >
          Enviados
        </button>
      </div>
    </div>

    <div class="flex-1 overflow-y-auto">
      <EmptyState
        v-if="shares.isLoading && shares.shares.length === 0"
        title="Cargando…"
      >
        <template #icon>
          <div class="h-6 w-6 animate-spin rounded-full border-2 border-surface-2 border-t-primary" />
        </template>
      </EmptyState>

      <EmptyState
        v-else-if="visible.length === 0"
        :title="filter === 'sent' ? 'Sin shares enviados' : 'Sin shares recibidos'"
        :subtitle="
          filter === 'sent'
            ? 'Comparte un archivo con otro dispositivo para verlo aquí.'
            : 'Los archivos que te compartan aparecerán aquí.'
        "
      >
        <template #icon><Inbox :size="26" /></template>
      </EmptyState>

      <div v-else class="flex flex-col gap-2 px-6 pb-4">
        <CardTile v-for="share in visible" :key="share.id">
          <template #leading>
            <div class="flex h-10 w-10 items-center justify-center rounded-[10px] bg-surface-2 text-primary">
              <Share2 :size="18" />
            </div>
          </template>
          <template #title>
            <span class="truncate text-sm font-medium text-fg">{{ share.file?.name ?? "Archivo" }}</span>
          </template>
          <template #subtitle>
            <p class="mt-0.5 text-xs text-muted">
              {{ filter === 'sent' ? deviceName(share.targetDeviceId) : (deviceName(share.senderDeviceId)) }} · {{ shareStatusLabel(share.status) }}
            </p>
          </template>
          <template #trailing>
            <UiButton
              v-if="filter === 'received' && share.status === 'CREATED'"
              variant="secondary"
              @click="accept(share)"
            >
              Aceptar
            </UiButton>
            <button
              v-if="filter === 'received' && share.status !== 'EXPIRED' && share.status !== 'DOWNLOADED'"
              class="rounded-md p-2 text-muted hover:bg-surface-2 hover:text-fg"
              title="Descargar"
              @click="download(share)"
            >
              <CloudDownload :size="16" />
            </button>
            <button
              v-if="filter === 'sent' && share.status === 'CREATED'"
              class="rounded-md p-2 text-muted hover:bg-surface-2 hover:text-fg"
              title="Cancelar"
              @click="cancel(share)"
            >
              <XCircle :size="16" />
            </button>
          </template>
        </CardTile>
      </div>
    </div>
  </div>
</template>
