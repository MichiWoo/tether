<script setup lang="ts">
import EmptyState from "@/components/ui/EmptyState.vue";
import { FolderOpen } from "@lucide/vue";
</script>

<template>
  <EmptyState title="Archivos" subtitle="Próximamente.">
    <template #icon><FolderOpen :size="26" /></template>
  </EmptyState>
</template>
