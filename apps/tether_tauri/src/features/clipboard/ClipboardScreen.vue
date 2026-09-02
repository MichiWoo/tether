<script setup lang="ts">
import EmptyState from "@/components/ui/EmptyState.vue";
import { ClipboardPaste } from "@lucide/vue";
</script>

<template>
  <EmptyState title="Portapapeles" subtitle="Próximamente.">
    <template #icon><ClipboardPaste :size="26" /></template>
  </EmptyState>
</template>
