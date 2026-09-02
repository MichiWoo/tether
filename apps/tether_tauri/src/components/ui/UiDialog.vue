<script setup lang="ts">
import { X } from "@lucide/vue";

withDefaults(defineProps<{ title?: string; maxWidth?: string }>(), { maxWidth: "480px" });
defineEmits<{ (e: "close"): void }>();
</script>

<template>
  <Teleport to="body">
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-6" @click.self="$emit('close')">
      <div
        class="w-full rounded-2xl border border-border bg-bg shadow-2xl"
        :style="{ maxWidth }"
      >
        <div class="flex items-center justify-between px-5 pt-4">
          <h3 class="text-base font-semibold text-fg">{{ title }}</h3>
          <button class="rounded-md p-1 text-muted hover:bg-surface-2 hover:text-fg" @click="$emit('close')">
            <X :size="18" />
          </button>
        </div>
        <div class="px-5 py-4">
          <slot />
        </div>
        <div v-if="$slots.actions" class="flex justify-end gap-2 border-t border-border px-5 py-4">
          <slot name="actions" />
        </div>
      </div>
    </div>
  </Teleport>
</template>
