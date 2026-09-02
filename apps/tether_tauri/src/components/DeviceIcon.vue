<script setup lang="ts">
import { computed } from "vue";
import { Globe, Laptop, Monitor, Smartphone } from "@lucide/vue";

const props = defineProps<{ platform: string }>();

const icon = computed(() => {
  switch (props.platform.toUpperCase()) {
    case "IOS":
    case "ANDROID":
      return Smartphone;
    case "WINDOWS":
      return Monitor;
    case "WEB":
      return Globe;
    default:
      return Laptop;
  }
});
</script>

<template>
  <component :is="icon" v-bind="$attrs" />
</template>
