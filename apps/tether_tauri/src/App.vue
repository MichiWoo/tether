<script setup lang="ts">
import { onMounted, watch } from "vue";
import AuthScreen from "@/features/auth/AuthScreen.vue";
import HomeShell from "@/features/shell/HomeShell.vue";
import ToastHost from "@/components/ui/ToastHost.vue";
import { useAuthStore } from "@/stores/auth";
import { useDevicesStore } from "@/stores/devices";
import { realtime } from "@/core/realtime";
import { tokenStorage } from "@/core/storage";
import { defaultDeviceName, platformInfo, platformOsToWire } from "@/core/platform";

const auth = useAuthStore();
const devices = useDevicesStore();

onMounted(() => {
  void auth.bootstrap();
});

// Conecta/desconecta el realtime y registra este equipo al cambiar la sesión.
watch(
  () => auth.status,
  (status) => {
    if (status === "authenticated") {
      void (async () => {
        const token = await tokenStorage.readAccessToken();
        if (token) realtime.connect(token);
        devices.bind();
        const info = await platformInfo();
        await devices.ensureCurrentDevice(
          defaultDeviceName(info.os),
          platformOsToWire(info.os),
        );
        void devices.load();
      })();
    } else if (status !== "unknown" && status !== "authenticating") {
      realtime.disconnect();
    }
  },
);
</script>

<template>
  <div class="h-full w-full bg-bg">
    <div v-if="auth.isLoading" class="flex h-full items-center justify-center">
      <div class="h-8 w-8 animate-spin rounded-full border-2 border-surface-2 border-t-primary" />
    </div>

    <AuthScreen v-else-if="!auth.isAuthenticated" />
    <HomeShell v-else />

    <ToastHost />
  </div>
</template>
