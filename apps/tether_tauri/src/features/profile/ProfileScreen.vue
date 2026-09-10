<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from "vue";
import {
  Download,
  Image as ImageIcon,
  KeyRound,
  Lock,
  Mail,
  RefreshCw,
  Save,
  User,
} from "@lucide/vue";
import UiButton from "@/components/ui/UiButton.vue";
import UiInput from "@/components/ui/UiInput.vue";
import { showToast } from "@/components/ui/toast";
import { useAuthStore } from "@/stores/auth";
import { avatarFor, userDisplayName } from "@/core/types";
import { checkForUpdates, installUpdate, subscribeUpdater, type UpdateState } from "@/core/updater";
import PlanUsagePanel from "./PlanUsagePanel.vue";

const auth = useAuthStore();

const appVersion = import.meta.env.APP_VERSION as string;

const name = ref(auth.user?.name ?? "");
const avatarUrl = ref(auth.user?.avatarUrl ?? "");
const savingProfile = ref(false);
const avatarImgError = ref(false);

const current = ref("");
const next = ref("");
const confirm = ref("");
const changingPassword = ref(false);
const passwordError = ref<string | null>(null);

const updateState = ref<UpdateState>({ status: "idle" });
let unsubUpdate: (() => void) | null = null;

onMounted(() => {
  unsubUpdate = subscribeUpdater((state) => {
    updateState.value = state;
  });
});

onBeforeUnmount(() => {
  unsubUpdate?.();
});

const resolvedAvatar = computed(() => (auth.user ? avatarFor(auth.user) : ""));
const initial = computed(() => (auth.user ? userDisplayName(auth.user).charAt(0).toUpperCase() : ""));

async function saveProfile() {
  savingProfile.value = true;
  try {
    await auth.updateProfile({ name: name.value, avatarUrl: avatarUrl.value });
    avatarImgError.value = false;
    showToast("Perfil actualizado.", "success");
  } catch {
    showToast("No se pudo actualizar el perfil.", "error");
  } finally {
    savingProfile.value = false;
  }
}

function validatePassword(): boolean {
  if (next.value.length < 8) {
    passwordError.value = "Mínimo 8 caracteres";
    return false;
  }
  if (next.value !== confirm.value) {
    passwordError.value = "Las contraseñas no coinciden";
    return false;
  }
  passwordError.value = null;
  return true;
}

async function changePassword() {
  if (!validatePassword()) return;
  changingPassword.value = true;
  try {
    await auth.changePassword(current.value, next.value);
    current.value = "";
    next.value = "";
    confirm.value = "";
    passwordError.value = null;
    showToast("Contraseña actualizada.", "success");
  } catch {
    passwordError.value = "Contraseña actual incorrecta";
  } finally {
    changingPassword.value = false;
  }
}
</script>

<template>
  <div class="h-full overflow-y-auto px-5 py-4">
    <div class="flex max-w-xl flex-col gap-4">
      <!-- Uso y plan -->
      <PlanUsagePanel />

      <!-- Perfil -->
      <section class="border border-fg bg-bg shadow-1bit">
        <div class="flex items-center gap-2 border-b border-fg bg-fg px-4 py-2 text-bg">
          <User :size="14" />
          <span class="font-display text-xs uppercase tracking-wide">Perfil</span>
        </div>
        <div class="flex flex-col gap-4 p-4">
          <div class="flex items-center gap-4">
            <div class="dither-25 flex h-16 w-16 shrink-0 items-center justify-center overflow-hidden border border-fg bg-bg">
              <img
                v-if="resolvedAvatar && !avatarImgError"
                :src="resolvedAvatar"
                alt="Avatar"
                class="h-full w-full object-cover"
                @error="avatarImgError = true"
              />
              <span v-else class="font-display text-lg text-fg">{{ initial }}</span>
            </div>
            <div>
              <p class="font-display text-xs uppercase tracking-wide text-fg">
                {{ auth.user ? userDisplayName(auth.user) : "" }}
              </p>
              <p class="mt-1 font-mono text-xs text-muted">Gravatar por defecto</p>
            </div>
          </div>

          <UiInput v-model="name" label="Nombre" placeholder="Tu nombre">
            <template #leading><User :size="16" class="text-fg" /></template>
          </UiInput>

          <div>
            <label class="mb-1.5 block font-display text-[11px] uppercase tracking-wide text-fg">Email</label>
            <div class="flex items-center gap-2 border border-fg bg-surface-2 px-3 py-2">
              <Mail :size="16" class="text-muted" />
              <span class="font-mono text-sm text-muted">{{ auth.user?.email }}</span>
            </div>
          </div>

          <UiInput
            v-model="avatarUrl"
            label="Avatar (URL)"
            placeholder="https://ejemplo.com/avatar.png"
            @submit="saveProfile"
          >
            <template #leading><ImageIcon :size="16" class="text-fg" /></template>
          </UiInput>
          <p class="-mt-2 font-mono text-xs text-muted">Vacío = usar Gravatar automáticamente.</p>

          <div class="flex justify-end">
            <UiButton :disabled="savingProfile" @click="saveProfile">
              <Save :size="14" />
              Guardar
            </UiButton>
          </div>
        </div>
      </section>

      <!-- Contraseña -->
      <section class="border border-fg bg-bg shadow-1bit">
        <div class="flex items-center gap-2 border-b border-fg bg-fg px-4 py-2 text-bg">
          <KeyRound :size="14" />
          <span class="font-display text-xs uppercase tracking-wide">Contraseña</span>
        </div>
        <div class="flex flex-col gap-4 p-4">
          <UiInput v-model="current" label="Contraseña actual" type="password" placeholder="••••••••">
            <template #leading><Lock :size="16" class="text-fg" /></template>
          </UiInput>

          <UiInput v-model="next" label="Nueva contraseña" type="password" placeholder="Mínimo 8 caracteres" :error="passwordError">
            <template #leading><Lock :size="16" class="text-fg" /></template>
          </UiInput>

          <UiInput v-model="confirm" label="Confirmar contraseña" type="password" placeholder="Repite la nueva contraseña" @submit="changePassword">
            <template #leading><Lock :size="16" class="text-fg" /></template>
          </UiInput>

          <div class="flex justify-end">
            <UiButton :disabled="changingPassword" @click="changePassword">
              <KeyRound :size="14" />
              Cambiar contraseña
            </UiButton>
          </div>
        </div>
      </section>

      <!-- Actualizaciones -->
      <section class="border border-fg bg-bg shadow-1bit">
        <div class="flex items-center gap-2 border-b border-fg bg-fg px-4 py-2 text-bg">
          <Download :size="14" />
          <span class="font-display text-xs uppercase tracking-wide">Actualizaciones</span>
        </div>
        <div class="flex flex-col gap-3 p-4">
          <p class="font-mono text-xs text-muted">
            Versión actual:
            <span class="text-fg">{{ appVersion }}</span>
          </p>

          <p v-if="updateState.status === 'available'" class="border border-fg bg-surface-2 p-3 font-mono text-xs text-fg">
            Nueva versión disponible: v{{ updateState.version }}
            <span v-if="updateState.notes" class="mt-1 block text-muted">{{ updateState.notes }}</span>
          </p>
          <p v-if="updateState.status === 'upToDate'" class="font-mono text-xs text-muted">
            Estás en la última versión.
          </p>
          <p v-if="updateState.status === 'error'" class="border border-fg bg-surface-2 p-3 font-mono text-xs text-fg">
            {{ updateState.error }}
          </p>

          <div class="flex items-center gap-2">
            <UiButton
              v-if="updateState.status === 'available'"
              @click="installUpdate"
            >
              <Download :size="14" />
              Instalar
            </UiButton>
            <UiButton
              v-else
              variant="secondary"
              :disabled="updateState.status === 'checking'"
              @click="checkForUpdates"
            >
              <RefreshCw :size="14" />
              {{ updateState.status === "checking" ? "Buscando…" : "Buscar actualizaciones" }}
            </UiButton>
          </div>
        </div>
      </section>
    </div>
  </div>
</template>
