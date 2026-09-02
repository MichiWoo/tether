import { defineStore } from "pinia";
import {
  ENDPOINTS,
  friendlyError,
  http,
  isNetworkError,
  refreshHttp,
  setAccessToken,
} from "@/core/http";
import { tokenStorage } from "@/core/storage";
import type { User } from "@/core/types";

export type AuthStatus = "unknown" | "unauthenticated" | "authenticating" | "authenticated" | "offline";

interface AuthState {
  status: AuthStatus;
  user: User | null;
  error: string | null;
}

interface AuthResponse {
  accessToken: string;
  refreshToken: string;
  user: User;
}

export const useAuthStore = defineStore("auth", {
  state: (): AuthState => ({ status: "unknown", user: null, error: null }),

  getters: {
    isAuthenticated: (s) => s.status === "authenticated",
    isLoading: (s) => s.status === "unknown" || s.status === "authenticating",
    isOffline: (s) => s.status === "offline",
  },

  actions: {
    async bootstrap() {
      try {
        const access = await tokenStorage.readAccessToken();
        if (!access) {
          setAccessToken(null);
          this.status = "unauthenticated";
          return;
        }
        setAccessToken(access);
        const res = await http.get<User>(ENDPOINTS.authMe);
        this.user = res.data;
        this.status = "authenticated";
      } catch (e) {
        if (isNetworkError(e)) {
          this.status = "offline";
          this.error = friendlyError(e);
        } else {
          setAccessToken(null);
          this.status = "unauthenticated";
        }
      }
    },

    async retryBootstrap() {
      return this.bootstrap();
    },

    async login(email: string, password: string) {
      await this._authenticate(async () => {
        const res = await http.post<AuthResponse>(ENDPOINTS.authLogin, {
          email: email.trim(),
          password,
        });
        return res.data;
      });
    },

    async register(email: string, password: string, name?: string) {
      await this._authenticate(async () => {
        const res = await http.post<AuthResponse>(ENDPOINTS.authRegister, {
          email: email.trim(),
          password,
          ...(name && name.trim().length > 0 ? { name: name.trim() } : {}),
        });
        return res.data;
      });
    },

    async _authenticate(action: () => Promise<AuthResponse>) {
      this.status = "authenticating";
      this.error = null;
      try {
        const result = await action();
        await tokenStorage.saveTokens(result.accessToken, result.refreshToken);
        setAccessToken(result.accessToken);
        this.user = result.user;
        this.status = "authenticated";
      } catch (e) {
        this.status = "unauthenticated";
        this.error = friendlyError(e);
      }
    },

    async logout() {
      try {
        const refresh = await tokenStorage.readRefreshToken();
        if (refresh) {
          await refreshHttp.post(ENDPOINTS.authLogout, { refreshToken: refresh });
        }
      } catch {
        // El servidor puede estar caído; aún así limpiamos la sesión local.
      }
      await tokenStorage.clear();
      setAccessToken(null);
      this.user = null;
      this.status = "unauthenticated";
    },

    clearError() {
      this.error = null;
    },
  },
});
