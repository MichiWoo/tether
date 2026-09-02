<script setup lang="ts">
defineProps<{ title: string; subtitle?: string }>();
</script>

<template>
  <div class="flex h-full flex-col items-center justify-center gap-2 p-10 text-center">
    <div class="flex h-14 w-14 items-center justify-center rounded-2xl bg-surface-2 text-muted">
      <slot name="icon" />
    </div>
    <p class="text-base font-semibold text-fg">{{ title }}</p>
    <p v-if="subtitle" class="max-w-sm text-sm text-muted">{{ subtitle }}</p>
  </div>
</template>
