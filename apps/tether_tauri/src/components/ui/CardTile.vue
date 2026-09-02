<script setup lang="ts">
withDefaults(defineProps<{ clickable?: boolean; selected?: boolean }>(), {
  clickable: false,
  selected: false,
});
defineEmits<{ (e: "click"): void }>();
</script>

<template>
  <div
    class="flex items-center gap-3 border border-fg bg-bg px-4 py-3 transition-colors"
    :class="selected ? 'bg-fg text-bg' : clickable ? 'cursor-pointer hover:bg-surface-2' : ''"
    @click="$emit('click')"
  >
    <div v-if="$slots.leading" class="shrink-0"><slot name="leading" /></div>
    <div class="min-w-0 flex-1">
      <slot name="title" />
      <slot name="subtitle" />
    </div>
    <div v-if="$slots.trailing" class="flex shrink-0 items-center gap-1.5">
      <slot name="trailing" />
    </div>
  </div>
</template>
