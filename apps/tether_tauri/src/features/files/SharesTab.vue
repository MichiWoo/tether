<script setup lang="ts">
import { computed, ref } from "vue";
import { CloudDownload, Inbox, Share2, XCircle } from "@lucide/vue";
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
    const ok = await files.download({
      id: share.file?.id ?? share.id,
      name,
      mimeType: share.file?.mimeType ?? null,
      size: share.file?.size ?? 0,
      status: "UPLOADED",
      createdAt: share.createdAt,
    });
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
    <div class="flex items-center justify-between border-b border-fg px-5 py-3">
      <div class="flex border-2 border-fg" role="tablist" aria-label="Filtro de shares">
        <button
          role="tab"
          :aria-selected="filter === 'received'"
          class="px-4 py-1.5 [@media(pointer:coarse)]:px-5 [@media(pointer:coarse)]:py-3 font-display text-xs uppercase tracking-wide transition-colors"
          :class="filter === 'received' ? 'bg-fg text-bg' : 'bg-bg text-fg hover:bg-surface-2'"
          @click="filter = 'received'"
        >
          Recibidos
        </button>
        <button
          role="tab"
          :aria-selected="filter === 'sent'"
          class="border-l-2 border-fg px-4 py-1.5 [@media(pointer:coarse)]:px-5 [@media(pointer:coarse)]:py-3 font-display text-xs uppercase tracking-wide transition-colors"
          :class="filter === 'sent' ? 'bg-fg text-bg' : 'bg-bg text-fg hover:bg-surface-2'"
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
        <template #icon><div class="dither-50 h-6 w-6 border border-fg" /></template>
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

      <div v-else class="flex flex-col gap-2 px-5 py-3 [@media(pointer:coarse)]:gap-3 [@media(pointer:coarse)]:py-4">
        <CardTile v-for="share in visible" :key="share.id">
          <template #leading>
            <div class="flex h-9 w-9 items-center justify-center border border-fg">
              <Share2 :size="18" class="text-fg" />
            </div>
          </template>
          <template #title>
            <span class="truncate font-mono text-sm text-fg">{{ share.file?.name ?? "Archivo" }}</span>
          </template>
          <template #subtitle>
            <p class="mt-1 font-mono text-xs text-muted">
              {{ deviceName(filter === 'sent' ? share.targetDeviceId : share.senderDeviceId) }} ·
              {{ shareStatusLabel(share.status) }}
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
              class="border border-fg p-3 [@media(pointer:fine)]:p-2 hover:bg-surface-2"
              :aria-label="`Descargar ${share.file?.name ?? 'archivo'}`"
              title="Descargar"
              @click="download(share)"
            >
              <CloudDownload :size="15" />
            </button>
            <button
              v-if="filter === 'sent' && share.status === 'CREATED'"
              class="border border-fg p-3 [@media(pointer:fine)]:p-2 hover:bg-surface-2"
              :aria-label="`Cancelar share de ${share.file?.name ?? 'archivo'}`"
              title="Cancelar"
              @click="cancel(share)"
            >
              <XCircle :size="15" />
            </button>
          </template>
        </CardTile>
      </div>
    </div>
  </div>
</template>
