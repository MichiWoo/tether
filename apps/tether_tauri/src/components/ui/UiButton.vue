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
    "inline-flex items-center justify-center gap-2 rounded-lg text-sm font-medium transition-colors focus:outline-none focus-visible:ring-2 focus-visible:ring-primary/60 disabled:opacity-50 disabled:cursor-not-allowed px-3.5 py-2";
  const variants: Record<string, string> = {
    primary: "bg-primary text-primary-fg hover:bg-primary/85",
    secondary: "bg-surface-2 text-fg hover:bg-surface-2/75",
    ghost: "text-fg hover:bg-surface-2/60",
    destructive: "bg-destructive text-white hover:bg-destructive/85",
    outline: "border border-border text-fg hover:bg-surface-2/40",
  };
  return `${base} ${variants[props.variant]} ${props.block ? "w-full" : ""}`;
});
</script>

<template>
  <button :type="type" :disabled="disabled" :class="classes">
    <slot />
  </button>
</template>
