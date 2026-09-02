<script setup lang="ts">
import { onMounted, ref, watch } from "vue";
import { ClipboardPaste, Copy, Send } from "@lucide/vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import ErrorBanner from "@/components/ui/ErrorBanner.vue";
import CardTile from "@/components/ui/CardTile.vue";
import UiButton from "@/components/ui/UiButton.vue";
import UiInput from "@/components/ui/UiInput.vue";
import { showToast } from "@/components/ui/toast";
import { useClipboardStore } from "@/stores/clipboard";
import { useDevicesStore } from "@/stores/devices";
import { writeClipboard } from "@/core/clipboard";
import { formatDateTime } from "@/core/format";
import type { ClipboardItem } from "@/core/types";

const clipboard = useClipboardStore();
const devices = useDevicesStore();

const text = ref("");

onMounted(() => {
  clipboard.bind();
  void clipboard.loadHistory();
});

async function send() {
  const content = text.value.trim();
  if (!content) return;
  const deviceId = await devices.getLocalDeviceId();
  await clipboard.push(content, deviceId ?? undefined);
  text.value = "";
}

async function copy(item: ClipboardItem) {
  const ok = await writeClipboard(item.content);
  showToast(ok ? "Copiado en este dispositivo." : "El portapapeles no está disponible.", ok ? "success" : "error");
}

// Avisa cuando llega un item de otro dispositivo y se auto-copió.
watch(
  () => clipboard.autoCopied,
  (item) => {
    if (item) {
      showToast(`Copiado de ${item.sourceDeviceName ?? "otro dispositivo"}.`, "success");
      clipboard.clearAutoCopied();
    }
  },
);
</script>

<template>
  <div class="flex h-full flex-col">
    <div class="flex gap-2 px-6 pb-4 pt-1">
      <UiInput v-model="text" placeholder="Texto para enviar…" class="flex-1" @submit="send" />
      <UiButton @click="send"><Send :size="16" /> Enviar</UiButton>
    </div>

    <div v-if="clipboard.error" class="px-6 pb-3">
      <ErrorBanner :message="clipboard.error" />
    </div>

    <div class="flex-1 overflow-y-auto">
      <div v-if="clipboard.isLoading && clipboard.items.length === 0" class="flex h-full items-center justify-center">
        <div class="h-7 w-7 animate-spin rounded-full border-2 border-surface-2 border-t-primary" />
      </div>

      <EmptyState
        v-else-if="clipboard.items.length === 0"
        title="Sin historial"
        subtitle="Envía texto desde cualquier dispositivo para verlo aquí."
      >
        <template #icon><ClipboardPaste :size="26" /></template>
      </EmptyState>

      <div v-else class="flex flex-col gap-2 px-6 pb-4">
        <CardTile v-for="item in clipboard.items" :key="item.id" clickable @click="copy(item)">
          <template #title>
            <p class="line-clamp-3 whitespace-pre-wrap text-sm text-fg">{{ item.content }}</p>
          </template>
          <template #subtitle>
            <p class="mt-1 text-xs text-muted">
              {{ item.sourceDeviceName ?? "Desconocido" }} · {{ formatDateTime(item.createdAt) }}
            </p>
          </template>
          <template #trailing>
            <button class="rounded-md p-2 text-muted hover:bg-surface-2 hover:text-fg" @click.stop="copy(item)">
              <Copy :size="15" />
            </button>
          </template>
        </CardTile>
      </div>
    </div>
  </div>
</template>
