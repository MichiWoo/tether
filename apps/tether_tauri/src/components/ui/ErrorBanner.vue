<script setup lang="ts">
import { TriangleAlert } from "@lucide/vue";

defineProps<{ message: string }>();
</script>

<template>
  <div role="alert" aria-live="assertive" class="flex items-start gap-3 border border-fg bg-fg px-3.5 py-3 text-bg shadow-1bit-sm">
    <TriangleAlert :size="16" class="mt-0.5 shrink-0" />
    <span class="whitespace-pre-line font-mono text-sm">{{ message }}</span>
  </div>
</template>
