<script setup lang="ts">
import { onMounted } from "vue";
import AuthScreen from "@/features/auth/AuthScreen.vue";
import ToastHost from "@/components/ui/ToastHost.vue";
import UiButton from "@/components/ui/UiButton.vue";
import { useAuthStore } from "@/stores/auth";

const auth = useAuthStore();

onMounted(() => {
  void auth.bootstrap();
});
</script>

<template>
  <div class="h-full w-full bg-bg">
    <div v-if="auth.isLoading" class="flex h-full items-center justify-center">
      <div class="h-8 w-8 animate-spin rounded-full border-2 border-surface-2 border-t-primary" />
    </div>

    <AuthScreen v-else-if="!auth.isAuthenticated" />

    <!-- Placeholder: reemplazado por el HomeShell en la fase de dispositivos. -->
    <div v-else class="flex h-full flex-col items-center justify-center gap-4">
      <p class="text-fg">Conectado como {{ auth.user?.email }}</p>
      <UiButton variant="secondary" @click="auth.logout()">Cerrar sesión</UiButton>
    </div>

    <ToastHost />
  </div>
</template>
