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
    <label v-if="label" class="mb-1.5 block text-[13px] font-medium text-fg">{{ label }}</label>
    <div
      class="flex items-center gap-2 rounded-lg border bg-surface px-3 py-2 transition-colors"
      :class="error ? 'border-destructive' : 'border-border focus-within:border-primary'"
    >
      <slot name="leading" />
      <input
        :type="inputType"
        :value="modelValue"
        :placeholder="placeholder"
        :autofocus="autofocus"
        class="w-full bg-transparent text-sm text-fg placeholder:text-muted focus:outline-none"
        @input="onInput"
        @keyup.enter="emit('submit')"
      />
      <button
        v-if="isPassword"
        type="button"
        tabindex="-1"
        class="text-muted hover:text-fg"
        @click="showPassword = !showPassword"
      >
        <component :is="showPassword ? EyeOff : Eye" :size="16" />
      </button>
    </div>
    <p v-if="error" class="mt-1.5 flex items-center gap-1 text-xs text-destructive">
      <slot name="error">{{ error }}</slot>
    </p>
  </div>
</template>
