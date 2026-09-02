<script setup lang="ts">
import { computed } from "vue";

const props = withDefaults(
  defineProps<{
    variant?: "primary" | "secondary" | "ghost" | "destructive" | "outline";
    disabled?: boolean;
    block?: boolean;
    type?: "button" | "submit";
  }>(),
  { variant: "primary", disabled: false, block: false, type: "button" },
);

const classes = computed(() => {
  const base =
    "inline-flex items-center justify-center gap-2 border px-3.5 py-2 font-display text-xs uppercase tracking-wide transition-colors focus:outline-none focus-visible:ring-1 focus-visible:ring-fg disabled:cursor-not-allowed disabled:opacity-40";
  const variants: Record<string, string> = {
    primary: "border-fg bg-fg text-bg hover:bg-bg hover:text-fg",
    secondary: "border-fg bg-bg text-fg hover:bg-fg hover:text-bg",
    ghost: "border-transparent bg-transparent text-fg hover:bg-surface-2",
    destructive: "border-fg bg-fg text-bg hover:bg-bg hover:text-fg",
    outline: "border-fg bg-bg text-fg hover:bg-surface-2",
  };
  return `${base} ${variants[props.variant]} ${props.block ? "w-full" : ""}`;
});
</script>

<template>
  <button :type="type" :disabled="disabled" :class="classes">
    <slot />
  </button>
</template>
