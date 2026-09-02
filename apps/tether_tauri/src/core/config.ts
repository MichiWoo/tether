// Configuración global de la app.
// Se puede sobreescribir con VITE_API_BASE_URL (equivalente al --dart-define de Flutter).
export const AppConfig = {
  apiBaseUrl: (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? "http://localhost:3100",
  realtimePath: "/realtime",
};
