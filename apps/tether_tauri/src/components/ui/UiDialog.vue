<script setup lang="ts">
import { X } from "@lucide/vue";

withDefaults(defineProps<{ title?: string; maxWidth?: string }>(), { maxWidth: "480px" });
defineEmits<{ (e: "close"): void }>();
</script>

<template>
  <Teleport to="body">
    <div
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-6"
      @click.self="$emit('close')"
    >
      <div class="w-full border-2 border-fg bg-bg shadow-1bit" :style="{ maxWidth }">
        <div class="flex items-center justify-between border-b border-fg bg-fg px-4 py-2.5">
          <h3 class="font-display text-sm uppercase tracking-wide text-bg">{{ title }}</h3>
          <button class="text-bg hover:opacity-70" @click="$emit('close')">
            <X :size="16" />
          </button>
        </div>
        <div class="px-4 py-4">
          <slot />
        </div>
        <div v-if="$slots.actions" class="flex justify-end gap-2 border-t border-fg px-4 py-3">
          <slot name="actions" />
        </div>
      </div>
    </div>
  </Teleport>
</template>
