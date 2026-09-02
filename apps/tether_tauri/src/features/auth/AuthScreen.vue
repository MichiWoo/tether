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
  <div class="relative h-full w-full overflow-hidden bg-bg">
    <div
      class="absolute inset-0"
      style="background: linear-gradient(135deg, rgb(var(--primary) / 0.08), transparent 45%, rgb(var(--secondary) / 0.06))"
    />
    <ConstellationBackground />

    <div class="relative flex h-full items-center justify-center overflow-y-auto p-8">
      <div
        class="w-full max-w-[440px] rounded-[20px] border bg-surface p-8"
        style="box-shadow: 0 24px 48px rgb(var(--primary) / 0.10)"
      >
        <div class="flex flex-col items-center">
          <div
            class="flex h-[72px] w-[72px] items-center justify-center rounded-full border p-3.5"
            style="background-color: rgb(var(--primary) / 0.12); border-color: rgb(var(--primary) / 0.4)"
          >
            <img src="/logo.png" alt="Tether" class="h-11 w-11" />
          </div>
          <h1 class="mt-4 text-3xl font-extrabold tracking-tight text-fg">Tether</h1>
          <p class="mt-3 text-sm text-muted">Conecta tus dispositivos</p>
        </div>

        <div class="mt-7 flex rounded-xl bg-bg-2 p-1">
          <button
            class="flex-1 rounded-lg px-3 py-1.5 text-sm font-medium transition-colors"
            :class="isLogin() ? 'bg-surface-2 text-fg' : 'text-muted hover:text-fg'"
            @click="setMode('login')"
          >
            Iniciar sesión
          </button>
          <button
            class="flex-1 rounded-lg px-3 py-1.5 text-sm font-medium transition-colors"
            :class="!isLogin() ? 'bg-surface-2 text-fg' : 'text-muted hover:text-fg'"
            @click="setMode('register')"
          >
            Crear cuenta
          </button>
        </div>

        <div class="mt-6 flex flex-col gap-4">
          <UiInput v-if="!isLogin()" v-model="name" label="Nombre" placeholder="Nombre (opcional)">
            <template #leading><User :size="16" class="text-muted" /></template>
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
            <template #leading><Mail :size="16" class="text-muted" /></template>
          </UiInput>

          <UiInput
            v-model="password"
            label="Contraseña"
            placeholder="••••••••"
            type="password"
            :error="passwordError"
            @submit="submit"
          >
            <template #leading><Lock :size="16" class="text-muted" /></template>
          </UiInput>

          <div v-if="auth.error" class="flex flex-col gap-2">
            <ErrorBanner :message="auth.error" />
            <UiButton
              v-if="auth.isOffline"
              variant="ghost"
              :disabled="auth.isLoading"
              @click="auth.retryBootstrap()"
            >
              <RefreshCw :size="16" />
              Reintentar conexión
            </UiButton>
          </div>

          <UiButton
            class="mt-2 py-2.5"
            block
            :disabled="auth.isLoading"
            @click="submit"
          >
            <RefreshCw v-if="auth.isLoading" :size="16" class="animate-spin" />
            <component :is="isLogin() ? LogIn : UserPlus" v-else :size="16" />
            {{ isLogin() ? "Iniciar sesión" : "Crear cuenta" }}
          </UiButton>
        </div>
      </div>
    </div>
  </div>
</template>
