<script setup lang="ts">
import { onMounted, ref } from "vue";import {
  CloudDownload,
  CloudUpload,
  FileText,
  FolderOpen,
  Image,
  FileVideo,
  FileAudio,
  File,
  Share2,
  Trash2,
  X,
} from "@lucide/vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import ErrorBanner from "@/components/ui/ErrorBanner.vue";
import CardTile from "@/components/ui/CardTile.vue";
import ProgressBar from "@/components/ui/ProgressBar.vue";
import UiButton from "@/components/ui/UiButton.vue";
import UiDialog from "@/components/ui/UiDialog.vue";
import { showToast } from "@/components/ui/toast";
import { useFilesStore } from "@/stores/files";
import { useSharesStore } from "@/stores/shares";
import { useDevicesStore } from "@/stores/devices";
import { formatDateTime } from "@/core/format";
import { formatSize, isUploaded, type FileItem } from "@/core/types";
import SharesTab from "./SharesTab.vue";
import DeviceIcon from "@/components/DeviceIcon.vue";

const files = useFilesStore();
const shares = useSharesStore();
const devices = useDevicesStore();

const tab = ref<"files" | "shares">("files");
const deleteFile = ref<FileItem | null>(null);
const shareFile = ref<FileItem | null>(null);

const fileIcon = (mime?: string | null) => {
  const m = mime ?? "";
  if (m.startsWith("image")) return Image;
  if (m.startsWith("video")) return FileVideo;
  if (m.startsWith("audio")) return FileAudio;
  if (m.startsWith("text")) return FileText;
  return File;
};

const filePreviewKind = (mime?: string | null) => (mime ?? "").startsWith("image") ? "image" : mime;

onMounted(() => {
  files.bind();
  shares.bind();
  void files.load();
  void shares.load();
  void devices.load();
});

async function download(file: FileItem) {
  const ok = await files.download(file);
  showToast(ok ? "Descarga completada." : "No se pudo descargar el archivo.", ok ? "success" : "error");
}

async function confirmDelete() {
  const file = deleteFile.value;
  if (!file) return;
  try {
    await files.delete(file.id);
  } catch {
    showToast("No se pudo eliminar el archivo.", "error");
  }
  deleteFile.value = null;
}

async function openShare(file: FileItem) {
  shareFile.value = file;
  await devices.load();
}

async function confirmShare(targetDeviceId?: string) {
  const file = shareFile.value;
  if (!file) return;
  try {
    await shares.create(file.id, targetDeviceId);
    showToast("Archivo compartido.", "success");
  } catch {
    showToast("No se pudo compartir el archivo.", "error");
  }
  shareFile.value = null;
}
</script>

<template>
  <div class="flex h-full flex-col overflow-hidden">
    <!-- Colas de progreso -->
    <div v-if="files.downloads.length || files.uploads.length" class="flex flex-col gap-2 px-6 pt-3">
      <div
        v-for="t in files.downloads"
        :key="`d-${t.id}`"
        class="flex items-center gap-3 rounded-xl bg-surface px-4 py-3"
        :class="t.error ? 'bg-destructive/10' : ''"
      >
        <CloudDownload :size="18" :class="t.error ? 'text-destructive' : 'text-primary'" />
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm text-fg">{{ t.name }}</p>
          <div class="mt-1.5"><ProgressBar :value="t.progress" :error="!!t.error" /></div>
          <p v-if="t.error" class="mt-1 text-xs text-destructive">{{ t.error }}</p>
        </div>
        <button class="rounded-md p-1.5 text-muted hover:text-fg" @click="files.dismissDownload(t.id)">
          <X :size="14" />
        </button>
      </div>

      <div
        v-for="t in files.uploads"
        :key="`u-${t.id}`"
        class="flex items-center gap-3 rounded-xl bg-surface px-4 py-3"
        :class="t.error ? 'bg-destructive/10' : ''"
      >
        <CloudUpload :size="18" :class="t.error ? 'text-destructive' : 'text-primary'" />
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm text-fg">{{ t.name }}</p>
          <div class="mt-1.5"><ProgressBar :value="t.progress" :error="!!t.error" /></div>
          <p v-if="t.error" class="mt-1 text-xs text-destructive">{{ t.error }}</p>
        </div>
        <button class="rounded-md p-1.5 text-muted hover:text-fg" @click="files.dismissUpload(t.id)">
          <X :size="14" />
        </button>
      </div>
    </div>

    <!-- Pestañas -->
    <div class="flex items-center gap-3 px-6 py-3">
      <div class="flex rounded-xl bg-bg-2 p-1">
        <button
          class="rounded-lg px-4 py-1.5 text-sm font-medium transition-colors"
          :class="tab === 'files' ? 'bg-surface-2 text-fg' : 'text-muted hover:text-fg'"
          @click="tab = 'files'"
        >
          Mis archivos
        </button>
        <button
          class="rounded-lg px-4 py-1.5 text-sm font-medium transition-colors"
          :class="tab === 'shares' ? 'bg-surface-2 text-fg' : 'text-muted hover:text-fg'"
          @click="tab = 'shares'"
        >
          Compartidos
        </button>
      </div>
    </div>

    <div v-if="files.error" class="px-6 pb-3"><ErrorBanner :message="files.error" /></div>

    <!-- Mis archivos -->
    <div v-if="tab === 'files'" class="flex min-h-0 flex-1 flex-col">
      <div class="px-6 pb-2">
        <div class="flex items-center justify-between rounded-2xl bg-surface px-5 py-5">
          <div class="flex items-center gap-4">
            <CloudUpload :size="36" class="text-primary" />
            <div>
              <p class="text-sm font-semibold text-fg">Arrastra archivos aquí</p>
              <p class="text-xs text-muted">Se suben automáticamente a tu almacenamiento.</p>
            </div>
          </div>
          <UiButton variant="secondary" @click="files.pickAndUpload()">Seleccionar</UiButton>
        </div>
      </div>

      <div class="flex-1 overflow-y-auto">
        <EmptyState
          v-if="files.isLoading && files.files.length === 0"
          title="Cargando…"
        >
          <template #icon>
            <div class="h-6 w-6 animate-spin rounded-full border-2 border-surface-2 border-t-primary" />
          </template>
        </EmptyState>

        <EmptyState
          v-else-if="files.files.length === 0"
          title="Sin archivos"
          subtitle="Selecciona o arrastra archivos para empezar."
        >
          <template #icon><FolderOpen :size="26" /></template>
        </EmptyState>

        <div v-else class="flex flex-col gap-2 px-6 pb-4">
          <CardTile
            v-for="file in files.files"
            :key="file.id"
            @click="filePreviewKind(file.mimeType) === 'image' && download(file)"
          >
            <template #leading>
              <component :is="fileIcon(file.mimeType)" :size="20" class="text-primary" />
            </template>
            <template #title>
              <span class="truncate text-sm font-medium text-fg">{{ file.name }}</span>
            </template>
            <template #subtitle>
              <p class="mt-0.5 font-mono text-xs text-muted">
                {{ formatSize(file.size) }} · {{ formatDateTime(file.createdAt) }}
              </p>
              <p v-if="!isUploaded(file)" class="text-xs text-destructive">Pendiente</p>
            </template>
            <template #trailing>
              <button
                v-if="isUploaded(file)"
                class="rounded-md p-2 text-muted hover:bg-surface-2 hover:text-fg"
                title="Compartir con un dispositivo"
                @click.stop="openShare(file)"
              >
                <Share2 :size="15" />
              </button>
              <button
                v-if="isUploaded(file)"
                class="rounded-md p-2 text-muted hover:bg-surface-2 hover:text-fg"
                title="Descargar"
                @click.stop="download(file)"
              >
                <CloudDownload :size="15" />
              </button>
              <button
                class="rounded-md p-2 text-muted hover:bg-surface-2 hover:text-destructive"
                title="Eliminar"
                @click.stop="deleteFile = file"
              >
                <Trash2 :size="15" />
              </button>
            </template>
          </CardTile>
        </div>
      </div>
    </div>

    <!-- Compartidos -->
    <SharesTab v-else />

    <UiDialog v-if="deleteFile" title="Eliminar archivo" @close="deleteFile = null">
      <p class="text-sm text-fg">¿Eliminar "{{ deleteFile.name }}" del cloud?</p>
      <template #actions>
        <UiButton variant="ghost" @click="deleteFile = null">Cancelar</UiButton>
        <UiButton variant="destructive" @click="confirmDelete">Eliminar</UiButton>
      </template>
    </UiDialog>

    <UiDialog
      v-if="shareFile"
      :title="`Compartir '${shareFile.name}'`"
      @close="shareFile = null"
    >
      <div class="flex flex-col gap-2">
        <CardTile clickable @click="confirmShare()">
          <template #leading><DeviceIcon platform="WEB" :size="20" class="text-primary" /></template>
          <template #title><span class="text-sm font-medium text-fg">Todos los dispositivos</span></template>
          <template #subtitle><p class="text-xs text-muted">Notifica a todos tus dispositivos</p></template>
        </CardTile>

        <CardTile
          v-for="device in devices.devices"
          :key="device.id"
          clickable
          @click="confirmShare(device.id)"
        >
          <template #leading><DeviceIcon :platform="device.platform" :size="20" class="text-primary" /></template>
          <template #title><span class="text-sm font-medium text-fg">{{ device.name }}</span></template>
          <template #subtitle>
            <p class="text-xs" :class="device.isOnline ? 'text-success' : 'text-muted'">
              {{ device.isOnline ? "En línea" : "Desconectado" }}
            </p>
          </template>
        </CardTile>
      </div>
      <template #actions>
        <UiButton variant="ghost" @click="shareFile = null">Cancelar</UiButton>
      </template>
    </UiDialog>
  </div>
</template>
