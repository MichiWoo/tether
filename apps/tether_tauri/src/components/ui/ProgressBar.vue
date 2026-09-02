<script setup lang="ts">
import { computed } from "vue";

const props = withDefaults(defineProps<{ value: number; error?: boolean }>(), { error: false });

const pct = computed(() => Math.min(1, Math.max(0, props.value)) * 100);
</script>

<template>
  <div class="h-1.5 w-full overflow-hidden rounded-full bg-surface-2">
    <div
      class="h-full rounded-full transition-all"
      :class="error ? 'bg-destructive' : 'bg-primary'"
      :style="{ width: `${pct}%` }"
    />
  </div>
</template>
