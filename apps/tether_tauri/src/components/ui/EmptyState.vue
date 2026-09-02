<script setup lang="ts">
defineProps<{ title: string; subtitle?: string }>();
</script>

<template>
  <div class="flex h-full flex-col items-center justify-center gap-3 p-10 text-center">
    <div class="dither-25 flex h-16 w-16 items-center justify-center border border-fg bg-bg text-fg">
      <slot name="icon" />
    </div>
    <p class="font-display text-sm uppercase tracking-wide text-fg">{{ title }}</p>
    <p v-if="subtitle" class="max-w-sm font-mono text-xs text-muted">{{ subtitle }}</p>
  </div>
</template>
