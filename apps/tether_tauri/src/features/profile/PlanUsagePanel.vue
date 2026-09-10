<script setup lang="ts">
import { onMounted } from "vue";
import { Gauge, HardDrive, MonitorSmartphone, Share2, ClipboardPaste } from "@lucide/vue";
import { usePlansStore } from "@/stores/plans";
import { formatSize } from "@/core/types";

const plans = usePlansStore();

const PLAN_LABELS = { FREE: "Freemium", PRO: "Pro", UNLIMITS: "Unlimits" } as const;

onMounted(() => {
  void plans.load();
});
</script>

<template>
  <section class="border border-fg bg-bg shadow-1bit">
    <div class="flex items-center justify-between border-b border-fg bg-fg px-4 py-2 text-bg">
      <span class="flex items-center gap-2">
        <Gauge :size="14" />
        <span class="font-display text-xs uppercase tracking-wide">Uso y plan</span>
      </span>
      <span
        class="border border-bg px-2 py-0.5 font-display text-[10px] uppercase"
        :class="plans.usage && plans.usage.plan !== 'FREE' ? 'bg-bg text-fg' : 'text-bg'"
      >
        {{ plans.usage ? PLAN_LABELS[plans.usage.plan] : "…" }}
      </span>
    </div>

    <div v-if="plans.usage" class="flex flex-col gap-4 p-4">
      <!-- Storage -->
      <div class="flex flex-col gap-1.5">
        <div class="flex items-center justify-between">
          <span class="flex items-center gap-1.5 font-display text-[11px] uppercase text-fg">
            <HardDrive :size="13" /> Espacio
          </span>
          <span class="font-mono text-xs text-muted">
            {{ formatSize(plans.usage.storageUsedBytes) }} / {{ formatSize(plans.usage.limits.maxStorageBytes) }}
          </span>
        </div>
        <ProgressBar :value="plans.usage.storageUsedBytes / plans.usage.limits.maxStorageBytes" :error="plans.storagePct >= 100" />
      </div>

      <!-- Traspaso mensual -->
      <div class="flex flex-col gap-1.5">
        <div class="flex items-center justify-between">
          <span class="flex items-center gap-1.5 font-display text-[11px] uppercase text-fg">
            <Share2 :size="13" /> Traspaso del mes
          </span>
          <span class="font-mono text-xs text-muted">
            {{ formatSize(plans.usage.transferUsedThisMonthBytes) }} / {{ formatSize(plans.usage.limits.monthlyTransferBytes) }}
          </span>
        </div>
        <ProgressBar :value="plans.usage.transferUsedThisMonthBytes / plans.usage.limits.monthlyTransferBytes" :error="plans.transferPct >= 100" />
      </div>

      <!-- Dispositivos y clipboards en línea de datos -->
      <div class="grid grid-cols-2 gap-2">
        <div class="flex items-center gap-2 border border-fg bg-surface-2 px-3 py-2">
          <MonitorSmartphone :size="14" class="text-fg" />
          <div>
            <p class="font-mono text-sm text-fg">{{ plans.usage.devicesUsed }} / {{ plans.usage.limits.maxDevices }}</p>
            <p class="font-display text-[10px] uppercase tracking-wide text-muted">Dispositivos</p>
          </div>
        </div>
        <div class="flex items-center gap-2 border border-fg bg-surface-2 px-3 py-2">
          <ClipboardPaste :size="14" class="text-fg" />
          <div>
            <p class="font-mono text-sm text-fg">
              {{ plans.usage.clipboardItemsUsed }}
              <span class="text-muted">/ {{ plans.usage.limits.clipboardHistoryItems }}</span>
            </p>
            <p class="font-display text-[10px] uppercase tracking-wide text-muted">Portapapeles</p>
          </div>
        </div>
      </div>

      <p class="font-mono text-[11px] text-muted">
        Archivo máx: {{ formatSize(plans.usage.limits.maxFileSizeBytes) }} · Shares: {{ plans.usage.limits.shareTtlDays }} días
      </p>

      <p v-if="plans.error" class="border border-fg bg-surface-2 p-2 font-mono text-xs text-fg">{{ plans.error }}</p>
    </div>

    <div v-else class="flex flex-col gap-2 p-4">
      <div class="dither-50 h-4 w-2/3" />
      <div class="dither-50 h-2.5 w-full" />
      <div class="dither-50 h-2.5 w-full" />
    </div>
  </section>
</template>
