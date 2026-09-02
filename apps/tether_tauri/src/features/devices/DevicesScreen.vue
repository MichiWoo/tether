<script setup lang="ts">
import { onMounted, reactive } from "vue";
import { Plus, Pencil, Trash2, Circle, CircleDot, MonitorSmartphone } from "@lucide/vue";
import CardTile from "@/components/ui/CardTile.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import ErrorBanner from "@/components/ui/ErrorBanner.vue";
import StatusChip from "@/components/ui/StatusChip.vue";
import UiButton from "@/components/ui/UiButton.vue";
import UiDialog from "@/components/ui/UiDialog.vue";
import UiInput from "@/components/ui/UiInput.vue";
import DeviceIcon from "@/components/DeviceIcon.vue";
import { useDevicesStore } from "@/stores/devices";
import { platformInfo, platformOsLabel } from "@/core/platform";
import { devicePlatformLabel, type Device } from "@/core/types";

const devices = useDevicesStore();

interface DialogState {
  type: "register" | "rename" | "delete" | null;
  device: Device | null;
  name: string;
}

const dialog = reactive<DialogState>({ type: null, device: null, name: "" });

const statusColor = (online: boolean) =>
  online
    ? { color: "rgb(var(--success) / 0.15)", foreground: "rgb(var(--success))" }
    : { color: "rgb(var(--surface-2))", foreground: "rgb(var(--muted))" };

function openRegister() {
  dialog.type = "register";
  dialog.device = null;
  dialog.name = "";
}

function openRename(device: Device) {
  dialog.type = "rename";
  dialog.device = device;
  dialog.name = device.name;
}

function openDelete(device: Device) {
  dialog.type = "delete";
  dialog.device = device;
  dialog.name = "";
}

function closeDialog() {
  dialog.type = null;
  dialog.device = null;
  dialog.name = "";
}

async function submit() {
  const type = dialog.type;
  if (type === "register") {
    const info = await platformInfo();
    await devices.register(dialog.name.trim(), platformOsLabel(info.os).toUpperCase());
  } else if (type === "rename" && dialog.device) {
    await devices.rename(dialog.device.id, dialog.name.trim());
  } else if (type === "delete" && dialog.device) {
    await devices.remove(dialog.device.id);
  }
  closeDialog();
}

onMounted(() => {
  void devices.load();
});
</script>

<template>
  <div class="flex h-full flex-col">
    <div class="flex items-center justify-between px-6 pb-4 pt-2">
      <span class="font-mono text-[13px] text-muted">{{ devices.devices.length }} dispositivo(s)</span>
      <UiButton @click="openRegister"><Plus :size="16" /> Registrar</UiButton>
    </div>

    <div v-if="devices.error" class="px-6 pb-3">
      <ErrorBanner :message="devices.error" />
    </div>

    <div class="flex-1 overflow-y-auto">
      <EmptyState
        v-if="devices.devices.length === 0"
        title="Sin dispositivos"
        subtitle="Registra tu primer dispositivo para empezar."
      >
        <template #icon><MonitorSmartphone :size="26" /></template>
      </EmptyState>

      <div v-else class="flex flex-col gap-2 px-6 pb-4">
        <CardTile v-for="device in devices.devices" :key="device.id" clickable @click="openRename(device)">
          <template #leading>
            <div class="flex h-10 w-10 items-center justify-center rounded-[10px] bg-surface-2 text-muted">
              <DeviceIcon :platform="device.platform" :size="20" />
            </div>
          </template>
          <template #title>
            <div class="flex items-center gap-2">
              <span class="truncate text-[15px] font-medium text-fg">{{ device.name }}</span>
              <StatusChip
                v-if="device.id === devices.localDeviceId"
                label="Este equipo"
                :color="'rgb(var(--primary) / 0.16)'"
                :foreground="'rgb(var(--primary))'"
              />
            </div>
          </template>
          <template #subtitle>
            <p class="mt-0.5 font-mono text-xs text-muted">{{ devicePlatformLabel(device.platform) }}</p>
          </template>
          <template #trailing>
            <StatusChip
              :label="device.isOnline ? 'En línea' : 'Desconectado'"
              :color="statusColor(device.isOnline).color"
              :foreground="statusColor(device.isOnline).foreground"
            >
              <CircleDot v-if="device.isOnline" :size="12" />
              <Circle v-else :size="12" />
            </StatusChip>
            <button class="rounded-md p-1.5 text-muted hover:bg-surface-2 hover:text-fg" @click.stop="openRename(device)">
              <Pencil :size="15" />
            </button>
            <button class="rounded-md p-1.5 text-muted hover:bg-surface-2 hover:text-destructive" @click.stop="openDelete(device)">
              <Trash2 :size="15" />
            </button>
          </template>
        </CardTile>
      </div>
    </div>

    <UiDialog
      v-if="dialog.type === 'register' || dialog.type === 'rename'"
      :title="dialog.type === 'register' ? 'Registrar dispositivo' : 'Renombrar dispositivo'"
      @close="closeDialog"
    >
      <UiInput
        v-model="dialog.name"
        label="Nombre"
        :placeholder="dialog.type === 'register' ? 'Ej. MacBook Pro' : 'Nombre'"
        :autofocus="true"
        @submit="submit"
      />
      <template #actions>
        <UiButton variant="ghost" @click="closeDialog">Cancelar</UiButton>
        <UiButton :disabled="!dialog.name.trim()" @click="submit">Guardar</UiButton>
      </template>
    </UiDialog>

    <UiDialog v-if="dialog.type === 'delete'" title="Eliminar dispositivo" @close="closeDialog">
      <p class="text-sm text-fg">
        ¿Eliminar "{{ dialog.device?.name }}"? Se desvinculará de tu cuenta.
      </p>
      <template #actions>
        <UiButton variant="ghost" @click="closeDialog">Cancelar</UiButton>
        <UiButton variant="destructive" @click="submit">Eliminar</UiButton>
      </template>
    </UiDialog>
  </div>
</template>
