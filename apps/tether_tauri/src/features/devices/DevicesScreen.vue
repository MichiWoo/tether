<script setup lang="ts">
import { onMounted, reactive } from "vue";
import { Plus, Pencil, Trash2, MonitorSmartphone } from "@lucide/vue";
import CardTile from "@/components/ui/CardTile.vue";
import EmptyState from "@/components/ui/EmptyState.vue";
import ErrorBanner from "@/components/ui/ErrorBanner.vue";
import StatusChip from "@/components/ui/StatusChip.vue";
import UiButton from "@/components/ui/UiButton.vue";
import UiDialog from "@/components/ui/UiDialog.vue";
import UiInput from "@/components/ui/UiInput.vue";
import DeviceIcon from "@/components/DeviceIcon.vue";
import { useDevicesStore } from "@/stores/devices";
import { platformInfo, platformOsToWire } from "@/core/platform";
import { devicePlatformLabel, type Device } from "@/core/types";

const devices = useDevicesStore();

interface DialogState {
  type: "register" | "rename" | "delete" | null;
  device: Device | null;
  name: string;
}

const dialog = reactive<DialogState>({ type: null, device: null, name: "" });

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
    await devices.register(dialog.name.trim(), platformOsToWire(info.os));
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
    <div class="flex items-center justify-between border-b border-fg px-5 py-3">
      <span class="font-mono text-xs text-fg">{{ devices.devices.length }} dispositivo(s)</span>
      <UiButton @click="openRegister"><Plus :size="14" /> Registrar</UiButton>
    </div>

    <div v-if="devices.error" class="px-5 pt-3">
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

      <div v-else class="flex flex-col gap-2 px-5 py-3">
        <CardTile v-for="device in devices.devices" :key="device.id" clickable @click="openRename(device)">
          <template #leading>
            <div class="flex h-9 w-9 items-center justify-center border border-fg">
              <DeviceIcon :platform="device.platform" :size="18" class="text-fg" />
            </div>
          </template>
          <template #title>
            <div class="flex items-center gap-2">
              <span class="truncate font-display text-xs uppercase tracking-wide text-fg">{{ device.name }}</span>
              <StatusChip v-if="device.id === devices.localDeviceId" label="Este equipo" variant="invert" />
            </div>
          </template>
          <template #subtitle>
            <p class="mt-1 font-mono text-xs text-muted">{{ devicePlatformLabel(device.platform) }}</p>
          </template>
          <template #trailing>
            <StatusChip
              :label="device.isOnline ? 'En línea' : 'Desconectado'"
              :variant="device.isOnline ? 'outline' : 'dim'"
              :indicator="device.isOnline ? 'filled' : 'hollow'"
            />
            <button class="border border-fg p-2 md:p-1.5 hover:bg-surface-2" :aria-label="`Renombrar ${device.name}`" @click.stop="openRename(device)">
              <Pencil :size="14" />
            </button>
            <button class="border border-fg p-2 md:p-1.5 hover:bg-surface-2" :aria-label="`Eliminar ${device.name}`" @click.stop="openDelete(device)">
              <Trash2 :size="14" />
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
      <p class="font-mono text-sm text-fg">
        ¿Eliminar "{{ dialog.device?.name }}"? Se desvinculará de tu cuenta.
      </p>
      <template #actions>
        <UiButton variant="ghost" @click="closeDialog">Cancelar</UiButton>
        <UiButton variant="destructive" @click="submit">Eliminar</UiButton>
      </template>
    </UiDialog>
  </div>
</template>
