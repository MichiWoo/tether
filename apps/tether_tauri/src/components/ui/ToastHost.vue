<script setup lang="ts">
import { CircleAlert, CircleCheck, Info, X } from "@lucide/vue";
import { toasts, dismissToast, type ToastKind } from "./toast";

function icon(kind: ToastKind) {
  switch (kind) {
    case "success":
      return CircleCheck;
    case "error":
      return CircleAlert;
    default:
      return Info;
  }
}

function tone(kind: ToastKind) {
  switch (kind) {
    case "success":
      return "text-success";
    case "error":
      return "text-destructive";
    default:
      return "text-info";
  }
}
</script>

<template>
  <div class="pointer-events-none fixed bottom-4 left-1/2 z-[60] flex -translate-x-1/2 flex-col items-center gap-2">
    <div
      v-for="toast in toasts"
      :key="toast.id"
      class="pointer-events-auto flex items-center gap-3 rounded-xl border border-border bg-surface px-4 py-3 text-sm text-fg shadow-lg"
    >
      <component :is="icon(toast.kind)" :size="16" :class="tone(toast.kind)" />
      <span>{{ toast.message }}</span>
      <button class="ml-1 text-muted hover:text-fg" @click="dismissToast(toast.id)">
        <X :size="14" />
      </button>
    </div>
  </div>
</template>
