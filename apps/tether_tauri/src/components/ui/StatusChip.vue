<script setup lang="ts">
withDefaults(
  defineProps<{
    label: string;
    color?: string;
    foreground?: string;
    dot?: boolean;
  }>(),
  { dot: false },
);
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium"
    :style="{ backgroundColor: color, color: foreground }"
  >
    <span v-if="dot" class="h-1.5 w-1.5 rounded-full" :style="{ backgroundColor: foreground }" />
    <slot>{{ label }}</slot>
  </span>
</template>
