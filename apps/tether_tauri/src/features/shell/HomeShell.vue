<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import {
  ClipboardPaste,
  FileInput,
  FolderOpen,
  LogOut,
  Moon,
  MonitorSmartphone,
  Sun,
} from "@lucide/vue";
import StatusChip from "@/components/ui/StatusChip.vue";
import DevicesScreen from "@/features/devices/DevicesScreen.vue";
import ClipboardScreen from "@/features/clipboard/ClipboardScreen.vue";
import FilesScreen from "@/features/files/FilesScreen.vue";
import { useAuthStore } from "@/stores/auth";
import { useFilesStore } from "@/stores/files";
import { useUiStore, type Section } from "@/stores/ui";
import { realtime } from "@/core/realtime";
import { userDisplayName } from "@/core/types";

const auth = useAuthStore();
const ui = useUiStore();
const filesStore = useFilesStore();

const rtStatus = computed(() => realtime.status.value);
const menuOpen = ref(false);
const dragging = ref(false);

let unlistenDrop: UnlistenFn | null = null;
let unlistenEnter: UnlistenFn | null = null;

// Archivos soltados sobre la ventana (escritorio) → subir a la pestaña Archivos.
onMounted(async () => {
  unlistenEnter = await listen<boolean>("file-drop-enter", (event) => {
    dragging.value = event.payload;
  });
  unlistenDrop = await listen<{ paths: string[] }>("file-drop", (event) => {
    dragging.value = false;
    void (async () => {
      for (const path of event.payload.paths) {
        await filesStore.uploadPath(path);
      }
      await filesStore.load();
    })();
  });
});

onBeforeUnmount(() => {
  unlistenDrop?.();
  unlistenEnter?.();
});

const sections: Array<{ key: Section; label: string; icon: typeof ClipboardPaste }> = [
  { key: "devices", label: "Dispositivos", icon: MonitorSmartphone },
  { key: "clipboard", label: "Portapapeles", icon: ClipboardPaste },
  { key: "files", label: "Archivos", icon: FolderOpen },
];

const sectionTitle = computed(() => sections.find((s) => s.key === ui.section)?.label ?? "");

const realtimeBadge = computed(() => {
  switch (rtStatus.value) {
    case "connected":
      return { label: "En línea", color: "rgb(var(--success) / 0.15)", foreground: "rgb(var(--success))" };
    case "connecting":
      return { label: "Conectando…", color: "rgb(var(--warning) / 0.15)", foreground: "rgb(var(--warning))" };
    default:
      return { label: "Sin conexión", color: "rgb(var(--destructive) / 0.15)", foreground: "rgb(var(--destructive))" };
  }
});
</script>

<template>
  <div class="relative flex h-full w-full bg-bg">
    <!-- Barra lateral -->
    <aside class="flex w-[208px] shrink-0 flex-col bg-bg-2">
      <div class="flex items-center gap-2.5 px-4 pb-3 pt-5">
        <div class="flex h-[34px] w-[34px] items-center justify-center rounded-lg p-1.5" style="background-color: rgb(var(--primary) / 0.14)">
          <img src="/logo.png" alt="Tether" class="h-full w-full" />
        </div>
        <span class="text-lg font-extrabold tracking-tight text-fg">Tether</span>
      </div>

      <div class="px-4 pb-4">
        <StatusChip
          :label="realtimeBadge.label"
          :color="realtimeBadge.color"
          :foreground="realtimeBadge.foreground"
          dot
        />
      </div>

      <div class="h-px bg-border" />

      <nav class="flex flex-col gap-0.5 p-3">
        <button
          v-for="section in sections"
          :key="section.key"
          class="flex items-center gap-3 rounded-[10px] px-3 py-2.5 text-sm transition-colors"
          :class="ui.section === section.key ? 'bg-primary/16 text-fg font-semibold' : 'text-muted hover:bg-surface-2/60 hover:text-fg'"
          @click="ui.setSection(section.key)"
        >
          <component :is="section.icon" :size="18" />
          {{ section.label }}
        </button>
      </nav>
    </aside>

    <div class="h-full w-px bg-border" />

    <!-- Contenido -->
    <div class="flex min-w-0 flex-1 flex-col">
      <header class="flex items-center justify-between px-6 py-3">
        <h2 class="text-lg font-bold tracking-tight text-fg">{{ sectionTitle }}</h2>
        <div class="flex items-center gap-1">
          <button
            class="rounded-md p-2 text-muted hover:bg-surface-2 hover:text-fg"
            @click="ui.toggleTheme()"
          >
            <Moon v-if="ui.theme === 'dark'" :size="18" />
            <Sun v-else :size="18" />
          </button>

          <div class="relative">
            <button
              class="flex items-center gap-2 rounded-md p-2 text-muted hover:bg-surface-2 hover:text-fg"
              @click="menuOpen = !menuOpen"
            >
              <span class="text-sm">{{ userDisplayName(auth.user!) }}</span>
            </button>
            <div
              v-if="menuOpen"
              class="absolute right-0 top-full z-40 mt-1 w-56 overflow-hidden rounded-xl border border-border bg-surface shadow-xl"
            >
              <div class="px-4 py-3">
                <p class="truncate text-sm font-semibold text-fg">{{ userDisplayName(auth.user!) }}</p>
                <p class="truncate text-xs text-muted">{{ auth.user?.email }}</p>
              </div>
              <div class="h-px bg-border" />
              <button
                class="flex w-full items-center gap-2 px-4 py-2.5 text-sm text-fg hover:bg-surface-2"
                @click="auth.logout()"
              >
                <LogOut :size="16" />
                Cerrar sesión
              </button>
            </div>
            <div v-if="menuOpen" class="fixed inset-0 z-30" @click="menuOpen = false" />
          </div>
        </div>
      </header>

      <div class="h-px bg-border" />

      <main class="min-h-0 flex-1">
        <DevicesScreen v-if="ui.section === 'devices'" />
        <ClipboardScreen v-else-if="ui.section === 'clipboard'" />
        <FilesScreen v-else />
      </main>
    </div>

    <!-- Overlay de arrastre -->
    <div
      v-if="dragging"
      class="pointer-events-none absolute inset-0 z-50 flex items-center justify-center"
      style="background-color: rgb(var(--primary) / 0.08)"
    >
      <div class="flex flex-col items-center gap-3 rounded-2xl border-2 border-primary bg-surface px-8 py-6">
        <FileInput :size="40" class="text-primary" />
        <span class="text-base font-medium text-fg">Suelta para subir</span>
      </div>
    </div>
  </div>
</template>
