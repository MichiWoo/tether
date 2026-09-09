<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from "vue";
import { X } from "@lucide/vue";

const props = withDefaults(defineProps<{ title?: string; maxWidth?: string }>(), {
  maxWidth: "480px",
});
const emit = defineEmits<{ (e: "close"): void }>();

const panel = ref<HTMLElement | null>(null);

function focusables(): HTMLElement[] {
  if (!panel.value) return [];
  return Array.from(
    panel.value.querySelectorAll<HTMLElement>(
      'a[href], button:not([disabled]), input:not([disabled]), select, textarea, [tabindex]:not([tabindex="-1"])',
    ),
  ).filter((el) => el.offsetParent !== null || el === document.activeElement);
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === "Escape") {
    event.stopPropagation();
    emit("close");
    return;
  }
  if (event.key !== "Tab") return;
  const list = focusables();
  if (list.length === 0) return;
  const first = list[0];
  const last = list[list.length - 1];
  const active = document.activeElement;
  if (event.shiftKey && active === first) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && active === last) {
    event.preventDefault();
    first.focus();
  }
}

let previousFocus: HTMLElement | null = null;

onMounted(() => {
  previousFocus = document.activeElement as HTMLElement | null;
  const target = focusables()[0];
  if (target) target.focus();
  else panel.value?.focus();
});

onBeforeUnmount(() => {
  previousFocus?.focus?.();
});
</script>

<template>
  <Teleport to="body">
    <div
      class="dither-50 fixed inset-0 z-50 flex items-center justify-center p-4 md:p-6"
      @click.self="$emit('close')"
    >
      <div
        ref="panel"
        role="dialog"
        aria-modal="true"
        :aria-label="title"
        tabindex="-1"
        class="w-full border-2 border-fg bg-bg shadow-1bit focus:outline-none"
        :style="{ maxWidth }"
        @keydown="onKeydown"
      >
        <div class="flex items-center justify-between border-b border-fg bg-fg px-4 py-2.5">
          <h3 class="font-display text-sm uppercase tracking-wide text-bg">
            {{ title }}
          </h3>
          <button class="p-1.5 text-bg hover:opacity-70" aria-label="Cerrar" @click="$emit('close')">
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
