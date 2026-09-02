<script setup lang="ts">
import { TriangleAlert } from "@lucide/vue";

defineProps<{ message: string }>();
</script>

<template>
  <div class="flex items-start gap-3 rounded-xl bg-destructive/15 px-3.5 py-3 text-sm text-destructive">
    <TriangleAlert :size="16" class="mt-0.5 shrink-0" />
    <span class="whitespace-pre-line">{{ message }}</span>
  </div>
</template>
