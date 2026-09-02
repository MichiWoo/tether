<script setup lang="ts">
import { TriangleAlert, CircleCheck, Info, X } from "@lucide/vue";
import { toasts, dismissToast, type ToastKind } from "./toast";

function icon(kind: ToastKind) {
  switch (kind) {
    case "success":
      return CircleCheck;
    case "error":
      return TriangleAlert;
    default:
      return Info;
  }
}
</script>

<template>
  <div class="pointer-events-none fixed bottom-4 left-1/2 z-[60] flex -translate-x-1/2 flex-col items-center gap-2">
    <div
      v-for="toast in toasts"
      :key="toast.id"
      class="pointer-events-auto flex items-center gap-3 border-2 border-fg bg-bg px-4 py-3 font-mono text-sm text-fg shadow-1bit"
    >
      <component :is="icon(toast.kind)" :size="16" />
      <span>{{ toast.message }}</span>
      <button class="ml-1 text-fg hover:opacity-60" @click="dismissToast(toast.id)">
        <X :size="14" />
      </button>
    </div>
  </div>
</template>
