<script setup lang="ts">
import { onMounted, ref, watch } from "vue";
import { ChevronDown, ChevronUp, ClipboardPaste, Copy, Send } from "@lucide/vue";
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
// Paste largos: solo se expande el ítem que el usuario pide.
const expanded = ref<Set<string>>(new Set());

const LONG_ITEM = 320;

const isLong = (item: ClipboardItem) => item.content.length > LONG_ITEM;
const isCollapsed = (item: ClipboardItem) =>
  isLong(item) && !expanded.value.has(item.id);

function toggle(item: ClipboardItem) {
  const next = new Set(expanded.value);
  if (next.has(item.id)) {
    next.delete(item.id);
  } else {
    next.add(item.id);
  }
  expanded.value = next;
}

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
  showToast(
    ok ? "Copiado en este dispositivo." : "El portapapeles no está disponible.",
    ok ? "success" : "error",
  );
}

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
    <div class="flex gap-2 border-b border-fg px-5 py-3">
      <UiInput v-model="text" placeholder="Texto para enviar…" class="flex-1" @submit="send" />
      <UiButton @click="send"><Send :size="14" /> Enviar</UiButton>
    </div>

    <div v-if="clipboard.error" class="px-5 pt-3">
      <ErrorBanner :message="clipboard.error" />
    </div>

    <div class="flex-1 overflow-y-auto">
      <div v-if="clipboard.isLoading && clipboard.items.length === 0" class="flex h-full items-center justify-center">
        <div class="dither-50 h-7 w-7 border border-fg" />
      </div>

      <EmptyState
        v-else-if="clipboard.items.length === 0"
        title="Sin historial"
        subtitle="Envía texto desde cualquier dispositivo para verlo aquí."
      >
        <template #icon><ClipboardPaste :size="26" /></template>
      </EmptyState>

      <div v-else class="flex flex-col gap-2 px-5 py-3">
        <CardTile
          v-for="item in clipboard.items"
          :key="item.id"
          clickable
          :aria-label="`Copiar: ${item.content.slice(0, 80)}`"
          @click="copy(item)"
        >
          <template #title>
            <p
              class="whitespace-pre-wrap font-mono text-sm text-fg"
              :class="isCollapsed(item) ? 'max-h-24 overflow-hidden [mask-image:linear-gradient(to_bottom,var(--ink)_70%,transparent)]' : ''"
            >{{ item.content }}</p>
          </template>
          <template #subtitle>
            <p class="mt-1 font-mono text-xs text-muted">
              {{ item.sourceDeviceName ?? "Desconocido" }} · {{ formatDateTime(item.createdAt) }}
            </p>
          </template>
          <template #trailing>
            <div class="flex items-center gap-1.5">
              <button
                v-if="isLong(item)"
                class="border border-fg p-2.5 md:p-2 hover:bg-surface-2"
                :aria-label="isCollapsed(item) ? 'Expandir ítem' : 'Colapsar ítem'"
                @click.stop="toggle(item)"
              >
                <component :is="isCollapsed(item) ? ChevronDown : ChevronUp" :size="14" />
              </button>
              <button
                class="border border-fg p-2.5 md:p-2 hover:bg-surface-2"
                aria-label="Copiar al portapapeles"
                @click.stop="copy(item)"
              >
                <Copy :size="14" />
              </button>
            </div>
          </template>
        </CardTile>
      </div>
    </div>
  </div>
</template>
