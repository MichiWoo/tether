<script setup lang="ts">
import { onMounted, ref } from "vue";
import {
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
    <div v-if="files.downloads.length || files.uploads.length" class="flex flex-col gap-2 px-5 pt-3">
      <div
        v-for="t in files.downloads"
        :key="`d-${t.id}`"
        class="flex items-center gap-3 border border-fg bg-bg px-3 py-2.5"
      >
        <CloudDownload :size="18" class="text-fg" />
        <div class="min-w-0 flex-1">
          <p class="truncate font-mono text-sm text-fg">{{ t.name }}</p>
          <div class="mt-1.5"><ProgressBar :value="t.progress" :error="!!t.error" /></div>
          <p v-if="t.error" class="mt-1 font-mono text-xs text-fg">{{ t.error }}</p>
        </div>
        <button
          class="border border-fg p-1.5 md:p-1 hover:bg-surface-2"
          :aria-label="`Descartar descarga ${t.name}`"
          @click="files.dismissDownload(t.id)"
        >
          <X :size="14" />
        </button>
      </div>

      <div
        v-for="t in files.uploads"
        :key="`u-${t.id}`"
        class="flex items-center gap-3 border border-fg bg-bg px-3 py-2.5"
      >
        <CloudUpload :size="18" class="text-fg" />
        <div class="min-w-0 flex-1">
          <p class="truncate font-mono text-sm text-fg">{{ t.name }}</p>
          <div class="mt-1.5"><ProgressBar :value="t.progress" :error="!!t.error" /></div>
          <p v-if="t.error" class="mt-1 font-mono text-xs text-fg">{{ t.error }}</p>
        </div>
        <button
          class="border border-fg p-1.5 md:p-1 hover:bg-surface-2"
          :aria-label="`Descartar subida ${t.name}`"
          @click="files.dismissUpload(t.id)"
        >
          <X :size="14" />
        </button>
      </div>
    </div>

    <!-- Pestañas -->
    <div class="flex items-center border-b border-fg px-5 py-3">
      <div class="flex border-2 border-fg" role="tablist" aria-label="Secciones de archivos">
        <button
          role="tab"
          :aria-selected="tab === 'files'"
          class="px-4 py-1.5 font-display text-xs uppercase tracking-wide transition-colors"
          :class="tab === 'files' ? 'bg-fg text-bg' : 'bg-bg text-fg hover:bg-surface-2'"
          @click="tab = 'files'"
        >
          Mis archivos
        </button>
        <button
          role="tab"
          :aria-selected="tab === 'shares'"
          class="border-l-2 border-fg px-4 py-1.5 font-display text-xs uppercase tracking-wide transition-colors"
          :class="tab === 'shares' ? 'bg-fg text-bg' : 'bg-bg text-fg hover:bg-surface-2'"
          @click="tab = 'shares'"
        >
          Compartidos
        </button>
      </div>
    </div>

    <div v-if="files.error" class="px-5 pt-3"><ErrorBanner :message="files.error" /></div>

    <!-- Mis archivos -->
    <div v-if="tab === 'files'" class="flex min-h-0 flex-1 flex-col">
      <div class="px-5 pt-3">
        <div class="flex flex-col gap-3 border border-fg bg-bg px-4 py-4 sm:flex-row sm:items-center sm:justify-between">
          <div class="flex items-center gap-3">
            <div class="dither-25 flex h-12 w-12 shrink-0 items-center justify-center border border-fg bg-bg">
              <CloudUpload :size="24" class="text-fg" />
            </div>
            <div>
              <p class="font-display text-xs uppercase tracking-wide text-fg">Arrastra archivos aquí</p>
              <p class="mt-1 font-mono text-xs text-muted">Se suben a tu almacenamiento.</p>
            </div>
          </div>
          <UiButton variant="secondary" class="sm:ml-4" @click="files.pickAndUpload()">Seleccionar</UiButton>
        </div>
      </div>

      <div class="flex-1 overflow-y-auto">
        <EmptyState
          v-if="files.isLoading && files.files.length === 0"
          title="Cargando…"
        >
          <template #icon><div class="dither-50 h-6 w-6 border border-fg" /></template>
        </EmptyState>

        <EmptyState
          v-else-if="files.files.length === 0"
          title="Sin archivos"
          subtitle="Selecciona o arrastra archivos para empezar."
        >
          <template #icon><FolderOpen :size="26" /></template>
        </EmptyState>

        <div v-else class="flex flex-col gap-2 px-5 py-3">
          <CardTile
            v-for="file in files.files"
            :key="file.id"
            clickable
            @click="filePreviewKind(file.mimeType) === 'image' && download(file)"
          >
            <template #leading>
              <div class="flex h-9 w-9 items-center justify-center border border-fg">
                <component :is="fileIcon(file.mimeType)" :size="18" class="text-fg" />
              </div>
            </template>
            <template #title>
              <span class="truncate font-mono text-sm text-fg">{{ file.name }}</span>
            </template>
            <template #subtitle>
              <p class="mt-1 font-mono text-xs text-muted">
                {{ formatSize(file.size) }} · {{ formatDateTime(file.createdAt) }}
              </p>
              <p v-if="!isUploaded(file)" class="font-display text-[10px] uppercase text-fg">Pendiente</p>
            </template>
            <template #trailing>
              <button
                v-if="isUploaded(file)"
                class="border border-fg p-2.5 md:p-2 hover:bg-surface-2"
                :aria-label="`Compartir ${file.name}`"
                title="Compartir con un dispositivo"
                @click.stop="openShare(file)"
              >
                <Share2 :size="14" />
              </button>
              <button
                v-if="isUploaded(file)"
                class="border border-fg p-2.5 md:p-2 hover:bg-surface-2"
                :aria-label="`Descargar ${file.name}`"
                title="Descargar"
                @click.stop="download(file)"
              >
                <CloudDownload :size="14" />
              </button>
              <button
                class="border border-fg p-2.5 md:p-2 hover:bg-surface-2"
                :aria-label="`Eliminar ${file.name}`"
                title="Eliminar"
                @click.stop="deleteFile = file"
              >
                <Trash2 :size="14" />
              </button>
            </template>
          </CardTile>
        </div>
      </div>
    </div>

    <!-- Compartidos -->
    <SharesTab v-else />

    <UiDialog v-if="deleteFile" title="Eliminar archivo" @close="deleteFile = null">
      <p class="font-mono text-sm text-fg">¿Eliminar "{{ deleteFile.name }}" del cloud?</p>
      <template #actions>
        <UiButton variant="ghost" @click="deleteFile = null">Cancelar</UiButton>
        <UiButton variant="destructive" @click="confirmDelete">Eliminar</UiButton>
      </template>
    </UiDialog>

    <UiDialog v-if="shareFile" :title="`Compartir '${shareFile.name}'`" @close="shareFile = null">
      <div class="flex flex-col gap-2">
        <CardTile clickable @click="confirmShare()">
          <template #leading><DeviceIcon platform="WEB" :size="18" class="text-fg" /></template>
          <template #title><span class="font-display text-xs uppercase text-fg">Todos los dispositivos</span></template>
          <template #subtitle><p class="font-mono text-xs text-muted">Notifica a todos tus dispositivos</p></template>
        </CardTile>

        <CardTile
          v-for="device in devices.devices"
          :key="device.id"
          clickable
          @click="confirmShare(device.id)"
        >
          <template #leading><DeviceIcon :platform="device.platform" :size="18" class="text-fg" /></template>
          <template #title><span class="font-display text-xs uppercase text-fg">{{ device.name }}</span></template>
          <template #subtitle>
            <p class="font-mono text-xs" :class="device.isOnline ? 'text-fg' : 'text-muted'">
              {{ device.isOnline ? "■ En línea" : "□ Desconectado" }}
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
