<script setup lang="ts">
import { computed, onMounted } from "vue";
import {
  ClipboardPaste,
  CloudUpload,
  HardDrive,
  MonitorSmartphone,
  Share2,
} from "@lucide/vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import ErrorBanner from "@/components/ui/ErrorBanner.vue";
import { useStatsStore } from "@/stores/stats";
import { formatSize } from "@/core/types";

const stats = useStatsStore();

const countTiles = computed(() => [
  { key: "filesUploaded", label: "Archivos subidos", value: stats.stats?.filesUploaded ?? 0, icon: CloudUpload },
  { key: "shares", label: "Compartidos", value: stats.stats?.shares ?? 0, icon: Share2 },
  { key: "devices", label: "Dispositivos", value: stats.stats?.devices ?? 0, icon: MonitorSmartphone },
  { key: "clipboardItems", label: "Portapapeles", value: stats.stats?.clipboardItems ?? 0, icon: ClipboardPaste },
]);

onMounted(() => {
  void stats.load();
});
</script>

<template>
  <div class="flex h-full flex-col overflow-hidden">
    <div v-if="stats.error" class="px-5 pt-3">
      <ErrorBanner :message="stats.error" />
    </div>

    <div v-if="stats.isLoading && !stats.stats" class="flex-1">
      <EmptyState title="Cargando…">
        <template #icon><div class="dither-50 h-6 w-6 border border-fg" /></template>
      </EmptyState>
    </div>

    <div v-else-if="!stats.stats" class="flex-1">
      <EmptyState title="Sin datos" subtitle="Tus estadísticas aparecerán aquí." />
    </div>

    <div v-else class="flex-1 overflow-y-auto px-5 py-4">
      <!-- Datos transferidos -->
      <div class="border border-fg bg-bg p-4 shadow-1bit">
        <div class="flex items-center gap-3">
          <div class="dither-25 flex h-11 w-11 shrink-0 items-center justify-center border border-fg bg-bg">
            <HardDrive :size="22" class="text-fg" />
          </div>
          <div>
            <p class="font-display text-[11px] uppercase tracking-wide text-muted">Datos transferidos</p>
            <p class="mt-1 font-mono text-2xl text-fg">{{ formatSize(stats.stats.filesTotalSize) }}</p>
          </div>
        </div>
        <p class="mt-3 border-t border-fg pt-2 font-mono text-xs text-muted">
          Tamaño total de los archivos subidos a tu almacenamiento.
        </p>
      </div>

      <!-- Conteos -->
      <div class="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
        <div
          v-for="tile in countTiles"
          :key="tile.key"
          class="border border-fg bg-bg p-4 shadow-1bit"
        >
          <div class="flex items-center justify-between">
            <component :is="tile.icon" :size="18" class="text-fg" />
            <span class="h-2.5 w-2.5 border border-fg" />
          </div>
          <p class="mt-3 font-mono text-2xl text-fg">{{ tile.value }}</p>
          <p class="mt-1 font-display text-[10px] uppercase tracking-wide text-muted">{{ tile.label }}</p>
        </div>
      </div>
    </div>
  </div>
</template>
