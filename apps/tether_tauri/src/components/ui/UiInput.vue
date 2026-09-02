<script setup lang="ts">
import { computed, ref } from "vue";
import { Eye, EyeOff } from "@lucide/vue";

const props = withDefaults(
  defineProps<{
    modelValue: string;
    label?: string;
    placeholder?: string;
    type?: string;
    error?: string | null;
    autofocus?: boolean;
  }>(),
  { label: undefined, placeholder: undefined, type: "text", error: null, autofocus: false },
);

const emit = defineEmits<{
  (e: "update:modelValue", value: string): void;
  (e: "submit"): void;
}>();

const isPassword = computed(() => props.type === "password");
const showPassword = ref(false);
const inputType = computed(() => (isPassword.value && !showPassword.value ? "password" : "text"));

function onInput(event: Event) {
  emit("update:modelValue", (event.target as HTMLInputElement).value);
}
</script>

<template>
  <div class="w-full">
    <label v-if="label" class="mb-1.5 block font-display text-[11px] uppercase tracking-wide text-fg">
      {{ label }}
    </label>
    <div
      class="flex items-center gap-2 border border-fg bg-bg px-3 py-2"
      :class="error ? 'shadow-[inset_0_0_0_1px_rgb(var(--ink))]' : ''"
    >
      <slot name="leading" />
      <input
        :type="inputType"
        :value="modelValue"
        :placeholder="placeholder"
        :autofocus="autofocus"
        class="w-full bg-transparent font-mono text-sm text-fg placeholder:text-muted focus:outline-none"
        @input="onInput"
        @keyup.enter="emit('submit')"
      />
      <button
        v-if="isPassword"
        type="button"
        tabindex="-1"
        class="text-fg"
        @click="showPassword = !showPassword"
      >
        <component :is="showPassword ? EyeOff : Eye" :size="16" />
      </button>
    </div>
    <p v-if="error" class="mt-1.5 flex items-center gap-1.5 font-mono text-xs text-fg">
      <span class="inline-block h-2 w-2 bg-fg" />
      {{ error }}
    </p>
  </div>
</template>
