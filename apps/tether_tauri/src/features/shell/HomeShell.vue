<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import {
  ClipboardPaste,
  FolderOpen,
  LayoutDashboard,
  LogOut,
  Moon,
  MonitorSmartphone,
  Sun,
  User,
} from "@lucide/vue";
import DashboardScreen from "@/features/dashboard/DashboardScreen.vue";
import DevicesScreen from "@/features/devices/DevicesScreen.vue";
import ClipboardScreen from "@/features/clipboard/ClipboardScreen.vue";
import FilesScreen from "@/features/files/FilesScreen.vue";
import ProfileScreen from "@/features/profile/ProfileScreen.vue";
import { useAuthStore } from "@/stores/auth";
import { useFilesStore } from "@/stores/files";
import { useUiStore, type Section } from "@/stores/ui";
import { realtime } from "@/core/realtime";
import { avatarFor, userDisplayName } from "@/core/types";

const auth = useAuthStore();
const ui = useUiStore();
const filesStore = useFilesStore();

const rtStatus = computed(() => realtime.status.value);
const menuOpen = ref(false);
const dragging = ref(false);
const avatarErr = ref(false);

const avatarUrl = computed(() => (auth.user ? avatarFor(auth.user) : ""));
const avatarInitial = computed(() =>
  auth.user ? userDisplayName(auth.user).charAt(0).toUpperCase() : "",
);

function openProfile() {
  menuOpen.value = false;
  ui.setSection("profile");
}

let unlistenDrop: UnlistenFn | null = null;
let unlistenEnter: UnlistenFn | null = null;

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
  { key: "home", label: "Inicio", icon: LayoutDashboard },
  { key: "devices", label: "Dispositivos", icon: MonitorSmartphone },
  { key: "clipboard", label: "Portapapeles", icon: ClipboardPaste },
  { key: "files", label: "Archivos", icon: FolderOpen },
];

const sectionTitle = computed(() => {
  if (ui.section === "profile") return "Perfil";
  return sections.find((s) => s.key === ui.section)?.label ?? "";
});

const realtimeLabel = computed(() => {
  switch (rtStatus.value) {
    case "connected":
      return { text: "en línea", marker: "filled" as const };
    case "connecting":
      return { text: "conectando", marker: "striped" as const };
    default:
      return { text: "sin conexión", marker: "hollow" as const };
  }
});
</script>

<template>
  <div class="relative flex h-full w-full flex-col bg-bg">
    <!-- Barra de menú — Desktop -->
    <header
      class="safe-top hidden items-center gap-1 border-b border-fg bg-fg px-3 pb-2 pt-2 text-bg [@media(pointer:fine)]:flex"
      style="padding-top: calc(0.5rem + env(safe-area-inset-top, 0px))"
    >
      <div class="flex items-center gap-2 pr-3">
        <span class="flex items-center gap-px">
          <span class="h-2.5 w-2.5 bg-bg" />
          <span class="h-px w-1.5 bg-bg" />
          <span class="h-2.5 w-2.5 border border-bg" />
        </span>
        <span class="font-display text-sm font-bold tracking-wide">TETHER</span>
      </div>

      <button
        v-for="section in sections"
        :key="section.key"
        class="px-3 py-1 font-display text-xs uppercase tracking-wide transition-colors"
        :class="ui.section === section.key ? 'bg-bg text-fg' : 'hover:bg-bg/20'"
        @click="ui.setSection(section.key)"
      >
        {{ section.label }}
      </button>

      <div class="flex-1" />

      <span class="mr-3 flex items-center gap-1.5 font-mono text-xs">
        <span
          class="inline-block h-2 w-2"
          :class="
            realtimeLabel.marker === 'filled'
              ? 'bg-bg'
              : realtimeLabel.marker === 'hollow'
                ? 'border border-bg'
                : 'stripes-paper'
          "
        />
        {{ realtimeLabel.text }}
      </span>

      <button class="px-1.5 py-1 hover:bg-bg/20" @click="ui.toggleTheme()">
        <Moon v-if="ui.theme === 'dark'" :size="15" />
        <Sun v-else :size="15" />
      </button>

      <div class="relative">
        <button class="flex items-center gap-1.5 px-2 py-1 font-display text-xs uppercase hover:bg-bg/20" @click="menuOpen = !menuOpen">
          <span class="flex h-5 w-5 items-center justify-center overflow-hidden border border-bg">
            <img
              v-if="avatarUrl && !avatarErr"
              :src="avatarUrl"
              alt=""
              class="h-full w-full object-cover"
              @error="avatarErr = true"
            />
            <span v-else class="text-[10px] leading-none">{{ avatarInitial }}</span>
          </span>
          {{ userDisplayName(auth.user!) }}
        </button>
        <div
          v-if="menuOpen"
          class="absolute right-0 top-full z-40 mt-1 w-60 border-2 border-fg bg-bg text-fg shadow-1bit"
        >
          <div class="flex items-center gap-3 border-b border-fg px-4 py-2.5">
            <div class="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden border border-fg">
              <img
                v-if="avatarUrl && !avatarErr"
                :src="avatarUrl"
                alt=""
                class="h-full w-full object-cover"
                @error="avatarErr = true"
              />
              <span v-else class="font-display text-sm">{{ avatarInitial }}</span>
            </div>
            <div class="min-w-0">
              <p class="truncate font-display text-xs uppercase">{{ userDisplayName(auth.user!) }}</p>
              <p class="truncate font-mono text-xs text-muted">{{ auth.user?.email }}</p>
            </div>
          </div>
          <button
            class="flex w-full items-center gap-2 px-4 py-2.5 font-display text-xs uppercase hover:bg-surface-2"
            @click="openProfile"
          >
            <User :size="15" />
            Perfil
          </button>
          <button
            class="flex w-full items-center gap-2 px-4 py-2.5 font-display text-xs uppercase hover:bg-surface-2"
            @click="auth.logout()"
          >
            <LogOut :size="15" />
            Cerrar sesión
          </button>
        </div>
        <div v-if="menuOpen" class="fixed inset-0 z-30" @click="menuOpen = false" />
      </div>
    </header>

    <!-- Barra de menú — Mobile minimal -->
    <header
      class="safe-top hidden items-center justify-between border-b border-fg bg-fg px-3 pb-2 pt-2 text-bg [@media(pointer:coarse)]:flex"
      style="padding-top: calc(0.5rem + env(safe-area-inset-top, 0px))"
    >
      <div class="flex items-center gap-2">
        <span class="flex items-center gap-px">
          <span class="h-2 w-2 bg-bg" />
          <span class="h-px w-1 bg-bg" />
          <span class="h-2 w-2 border border-bg" />
        </span>
        <span class="font-display text-xs font-bold tracking-wide">TETHER</span>
        <span
          class="ml-1 inline-block h-1.5 w-1.5"
          :class="
            realtimeLabel.marker === 'filled'
              ? 'bg-bg'
              : realtimeLabel.marker === 'hollow'
                ? 'border border-bg'
                : 'stripes-paper'
          "
        />
      </div>
      <div class="flex items-center gap-2">
        <button class="p-2 hover:bg-bg/20" aria-label="Cambiar tema" @click="ui.toggleTheme()">
          <Moon v-if="ui.theme === 'dark'" :size="18" />
          <Sun v-else :size="18" />
        </button>
        <div class="relative">
          <button class="flex h-9 w-9 items-center justify-center overflow-hidden border border-bg" aria-label="Abrir menú de usuario" @click="menuOpen = !menuOpen">
            <img
              v-if="avatarUrl && !avatarErr"
              :src="avatarUrl"
              alt=""
              class="h-full w-full object-cover"
              @error="avatarErr = true"
            />
            <span v-else class="text-xs leading-none">{{ avatarInitial }}</span>
          </button>
          <div
            v-if="menuOpen"
            class="absolute right-0 top-full z-40 mt-1 w-60 border-2 border-fg bg-bg text-fg shadow-1bit"
          >
            <div class="flex items-center gap-3 border-b border-fg px-4 py-2.5">
              <div class="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden border border-fg">
                <img
                  v-if="avatarUrl && !avatarErr"
                  :src="avatarUrl"
                  alt=""
                  class="h-full w-full object-cover"
                  @error="avatarErr = true"
                />
                <span v-else class="font-display text-sm">{{ avatarInitial }}</span>
              </div>
              <div class="min-w-0">
                <p class="truncate font-display text-xs uppercase">{{ userDisplayName(auth.user!) }}</p>
                <p class="truncate font-mono text-xs text-muted">{{ auth.user?.email }}</p>
              </div>
            </div>
            <button
              class="flex w-full items-center gap-2 px-4 py-2.5 font-display text-xs uppercase hover:bg-surface-2"
              @click="openProfile"
            >
              <User :size="15" />
              Perfil
            </button>
            <button
              class="flex w-full items-center gap-2 px-4 py-2.5 font-display text-xs uppercase hover:bg-surface-2"
              @click="auth.logout()"
            >
              <LogOut :size="15" />
              Cerrar sesión
            </button>
          </div>
          <div v-if="menuOpen" class="fixed inset-0 z-30" @click="menuOpen = false" />
        </div>
      </div>
    </header>

    <!-- Ventana -->
    <main class="min-h-0 flex-1 p-3 pb-3 [@media(pointer:coarse)]:pb-[calc(4rem+env(safe-area-inset-bottom,0px))]">
      <div class="flex h-full flex-col border border-fg bg-bg shadow-1bit">
        <div class="flex items-center justify-between border-b border-fg bg-fg px-3 py-1.5 text-bg">
          <span class="font-display text-xs uppercase tracking-wide">{{ sectionTitle }}</span>
          <div class="flex items-center gap-1.5">
            <span class="h-2.5 w-2.5 border border-bg" />
            <span class="h-2.5 w-2.5 border border-bg" />
            <span class="h-2.5 w-2.5 bg-bg" />
          </div>
        </div>
        <div class="min-h-0 flex-1 overflow-hidden">
          <DashboardScreen v-if="ui.section === 'home'" />
          <DevicesScreen v-else-if="ui.section === 'devices'" />
          <ClipboardScreen v-else-if="ui.section === 'clipboard'" />
          <ProfileScreen v-else-if="ui.section === 'profile'" />
          <FilesScreen v-else />
        </div>
      </div>
    </main>

    <!-- Navegación inferior — Mobile (iconos solo) -->
    <nav
      class="fixed inset-x-0 bottom-0 z-40 hidden border-t-2 border-fg bg-fg h-16 [@media(pointer:coarse)]:flex"
      style="padding-bottom: env(safe-area-inset-bottom, 0px)"
      aria-label="Navegación principal"
    >
      <button
        v-for="section in sections"
        :key="section.key"
        :aria-label="section.label"
        :aria-current="ui.section === section.key ? 'page' : undefined"
        class="flex flex-1 flex-col items-center justify-center gap-1 py-1 transition-colors"
        :class="ui.section === section.key ? 'bg-bg text-fg' : 'text-bg/60 active:bg-bg/10'"
        @click="ui.setSection(section.key)"
      >
        <component :is="section.icon" :size="26" :stroke-width="ui.section === section.key ? 2.4 : 2" />
      </button>
    </nav>

    <!-- Overlay de arrastre -->
    <div
      v-if="dragging"
      class="pointer-events-none absolute inset-0 z-50 flex items-center justify-center bg-bg/60"
    >
      <div class="flex flex-col items-center gap-3 border-2 border-fg bg-bg px-10 py-7 shadow-1bit">
        <div class="dither-50 flex h-16 w-16 items-center justify-center border border-fg bg-bg">
          <FolderOpen :size="28" class="text-fg" />
        </div>
        <span class="font-display text-sm uppercase tracking-wide text-fg">Suelta para subir</span>
      </div>
    </div>
  </div>
</template>
