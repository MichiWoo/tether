import axios, { AxiosError, AxiosInstance, InternalAxiosRequestConfig } from "axios";
import { AppConfig } from "./config";
import { tokenStorage } from "./storage";

export const ENDPOINTS = {
  authRegister: "/auth/register",
  authLogin: "/auth/login",
  authRefresh: "/auth/refresh",
  authLogout: "/auth/logout",
  authMe: "/auth/me",
  devices: "/devices",
  clipboard: "/clipboard",
  clipboardLatest: "/clipboard/latest",
  clipboardHistory: "/clipboard/history",
  files: "/files",
  shares: "/shares",
} as const;

export const deviceById = (id: string) => `/devices/${id}`;
export const fileById = (id: string) => `/files/${id}`;
export const fileComplete = (id: string) => `/files/${id}/complete`;
export const filePreview = (id: string) => `/files/${id}/preview`;
export const shareById = (id: string) => `/shares/${id}`;
export const shareAccept = (id: string) => `/shares/${id}/accept`;
export const shareDownloaded = (id: string) => `/shares/${id}/downloaded`;
export const shareCancel = (id: string) => `/shares/${id}/cancel`;

// Token de acceso en memoria (cache síncrona para el interceptor).
let accessToken: string | null = null;

export function setAccessToken(token: string | null): void {
  accessToken = token;
}

export function getAccessToken(): string | null {
  return accessToken;
}

export class SessionExpiredError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "SessionExpiredError";
  }
}

function baseOptions() {
  return {
    baseURL: AppConfig.apiBaseUrl,
    timeout: 30_000,
    headers: { "Content-Type": "application/json", Accept: "application/json" },
  };
}

// Cliente sin interceptor de auth (refresh/logout, para evitar recursión).
export const refreshHttp: AxiosInstance = axios.create(baseOptions());

// Cliente autenticado con refresh automático ante 401.
export const http: AxiosInstance = axios.create(baseOptions());

let refreshInFlight: Promise<boolean> | null = null;

http.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  const isRefresh = config.url === ENDPOINTS.authRefresh;
  if (accessToken && !isRefresh) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});

http.interceptors.response.use(
  (res) => res,
  async (error: AxiosError) => {
    const status = error.response?.status;
    const isRefresh = error.config?.url === ENDPOINTS.authRefresh;

    if (status !== 401 || isRefresh) {
      return Promise.reject(error);
    }

    const ok = await ensureRefresh();
    if (!ok || !accessToken) {
      await tokenStorage.clear();
      setAccessToken(null);
      return Promise.reject(new SessionExpiredError("Tu sesión expiró. Inicia sesión de nuevo."));
    }

    const config = error.config!;
    config.headers.Authorization = `Bearer ${accessToken}`;
    return http.request(config);
  },
);

async function ensureRefresh(): Promise<boolean> {
  if (!refreshInFlight) {
    refreshInFlight = doRefresh().finally(() => {
      refreshInFlight = null;
    });
  }
  return refreshInFlight;
}

async function doRefresh(): Promise<boolean> {
  const refreshToken = await tokenStorage.readRefreshToken();
  if (!refreshToken) return false;
  try {
    const res = await refreshHttp.post(ENDPOINTS.authRefresh, { refreshToken });
    const data = res.data as { accessToken: string; refreshToken: string };
    await tokenStorage.saveTokens(data.accessToken, data.refreshToken);
    setAccessToken(data.accessToken);
    return true;
  } catch {
    return false;
  }
}

// Extrae un mensaje legible del error del backend.
export function friendlyError(error: unknown): string {
  if (error instanceof SessionExpiredError) return error.message;
  if (axios.isAxiosError(error)) {
    const data = error.response?.data as { message?: string | string[] } | undefined;
    if (data?.message) {
      if (Array.isArray(data.message)) return data.message.join("\n");
      if (data.message.length > 0) return data.message;
    }
    if (!error.response) {
      return `No se pudo conectar con el servidor. Verifica que el backend esté corriendo en ${AppConfig.apiBaseUrl}.`;
    }
  }
  return "Ocurrió un error inesperado. Intenta de nuevo.";
}

export function isNetworkError(error: unknown): boolean {
  return axios.isAxiosError(error) && !error.response;
}
