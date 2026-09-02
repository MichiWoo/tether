<script setup lang="ts">
withDefaults(
  defineProps<{
    label: string;
    variant?: "invert" | "outline" | "dim";
    indicator?: "filled" | "hollow" | "striped" | "none";
  }>(),
  { variant: "outline", indicator: "none" },
);
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 border border-fg px-2 py-0.5 font-display text-[10px] uppercase tracking-wide"
    :class="variant === 'invert' ? 'bg-fg text-bg' : variant === 'dim' ? 'text-muted' : 'text-fg'"
  >
    <span
      v-if="indicator !== 'none'"
      class="inline-block h-2 w-2"
      :class="
        indicator === 'filled'
          ? 'bg-fg'
          : indicator === 'hollow'
            ? 'border border-fg'
            : 'stripes'
      "
    />
    <slot>{{ label }}</slot>
  </span>
</template>
