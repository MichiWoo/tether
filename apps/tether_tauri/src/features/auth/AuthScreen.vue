<script setup lang="ts">
import { ref } from "vue";
import { LogIn, Mail, Lock, RefreshCw, User, UserPlus } from "@lucide/vue";
import ConstellationBackground from "@/components/ConstellationBackground.vue";
import UiButton from "@/components/ui/UiButton.vue";
import UiInput from "@/components/ui/UiInput.vue";
import ErrorBanner from "@/components/ui/ErrorBanner.vue";
import { useAuthStore } from "@/stores/auth";

const auth = useAuthStore();

const mode = ref<"login" | "register">("login");
const email = ref("");
const password = ref("");
const name = ref("");
const emailError = ref<string | null>(null);
const passwordError = ref<string | null>(null);

const isLogin = () => mode.value === "login";

function setMode(next: "login" | "register") {
  if (next === mode.value) return;
  mode.value = next;
  email.value = "";
  password.value = "";
  name.value = "";
  emailError.value = null;
  passwordError.value = null;
  auth.clearError();
}

function validate(): boolean {
  const e = email.value.trim();
  emailError.value = !e
    ? "Ingresa tu email"
    : !e.includes("@") || !e.includes(".")
      ? "Email no válido"
      : null;
  passwordError.value = password.value.length < 8 ? "Mínimo 8 caracteres" : null;
  return !emailError.value && !passwordError.value;
}

async function submit() {
  if (!validate()) return;
  if (mode.value === "login") {
    await auth.login(email.value, password.value);
  } else {
    await auth.register(email.value, password.value, name.value);
  }
}
</script>

<template>
  <div class="relative flex h-full w-full items-center justify-center overflow-y-auto bg-bg p-8">
    <ConstellationBackground />

    <div class="relative w-full max-w-[440px] border-2 border-fg bg-bg shadow-1bit">
      <!-- Título de ventana -->
      <div class="flex items-center justify-between border-b-2 border-fg bg-fg px-4 py-2.5 text-bg">
        <div class="flex items-center gap-2">
          <span class="flex items-center gap-px">
            <span class="h-2 w-2 bg-bg" />
            <span class="h-px w-1 bg-bg" />
            <span class="h-2 w-2 border border-bg" />
          </span>
          <span class="font-display text-xs uppercase tracking-wide">Tether</span>
        </div>
        <span class="font-display text-[10px] uppercase text-bg/85">
          {{ isLogin() ? "Iniciar sesión" : "Crear cuenta" }}
        </span>
      </div>

      <div class="flex flex-col gap-5 p-7">
        <div class="flex flex-col items-center gap-2 text-center">
          <p class="font-display text-xs uppercase tracking-wide text-fg">
            Copia aquí, pega allá
          </p>
          <p class="max-w-xs font-mono text-xs text-muted">
            Un solo escritorio para todos tus dispositivos.
          </p>
        </div>

        <div class="flex border-2 border-fg" role="tablist" aria-label="Modo de acceso">
          <button
            role="tab"
            :aria-selected="isLogin()"
            class="flex-1 px-3 py-2 font-display text-xs uppercase tracking-wide transition-colors"
            :class="isLogin() ? 'bg-fg text-bg' : 'bg-bg text-fg hover:bg-surface-2'"
            @click="setMode('login')"
          >
            Entrar
          </button>
          <button
            role="tab"
            :aria-selected="!isLogin()"
            class="flex-1 border-l-2 border-fg px-3 py-2 font-display text-xs uppercase tracking-wide transition-colors"
            :class="!isLogin() ? 'bg-fg text-bg' : 'bg-bg text-fg hover:bg-surface-2'"
            @click="setMode('register')"
          >
            Crear cuenta
          </button>
        </div>

        <div class="flex flex-col gap-4">
          <UiInput v-if="!isLogin()" v-model="name" label="Nombre" placeholder="Nombre (opcional)">
            <template #leading><User :size="16" class="text-fg" /></template>
          </UiInput>

          <UiInput
            v-model="email"
            label="Email"
            placeholder="tú@ejemplo.com"
            type="email"
            :autofocus="true"
            :error="emailError"
            @submit="submit"
          >
            <template #leading><Mail :size="16" class="text-fg" /></template>
          </UiInput>

          <UiInput
            v-model="password"
            label="Contraseña"
            placeholder="••••••••"
            type="password"
            :error="passwordError"
            @submit="submit"
          >
            <template #leading><Lock :size="16" class="text-fg" /></template>
          </UiInput>

          <div v-if="auth.error" class="flex flex-col gap-2" role="alert" aria-live="assertive">
            <ErrorBanner :message="auth.error" />
            <UiButton v-if="auth.isOffline" variant="secondary" :disabled="auth.isLoading" @click="auth.retryBootstrap()">
              <RefreshCw :size="14" />
              Reintentar conexión
            </UiButton>
          </div>

          <UiButton class="py-2.5" block :disabled="auth.isLoading" @click="submit">
            <RefreshCw v-if="auth.isLoading" :size="14" class="animate-spin" />
            <component :is="isLogin() ? LogIn : UserPlus" v-else :size="14" />
            {{ isLogin() ? "Iniciar sesión" : "Crear cuenta" }}
          </UiButton>
        </div>
      </div>
    </div>
  </div>
</template>
