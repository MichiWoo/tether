<script setup lang="ts">
import { computed } from "vue";

const props = withDefaults(defineProps<{ value: number; error?: boolean }>(), { error: false });

const pct = computed(() => Math.min(1, Math.max(0, props.value)) * 100);
</script>

<template>
  <div class="h-2.5 w-full border border-fg bg-bg p-px">
    <div
      class="h-full"
      :class="error ? 'hatch' : 'bg-fg'"
      :style="{ width: `${pct}%` }"
    />
  </div>
</template>
