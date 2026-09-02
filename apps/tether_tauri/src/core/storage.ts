import { invoke } from "@tauri-apps/api/core";

// Persistencia segura de secretos (Keychain/Keystore/Credential Manager)
// vía el comando Rust `keyring_*`.

const ACCESS_KEY = "access_token";
const REFRESH_KEY = "refresh_token";
const DEVICE_KEY = "local_device_id";

async function get(key: string): Promise<string | null> {
  return invoke<string | null>("keyring_get", { key });
}

async function set(key: string, value: string): Promise<void> {
  await invoke("keyring_set", { key, value });
}

async function del(key: string): Promise<void> {
  await invoke("keyring_delete", { key });
}

export interface TokenStorage {
  readAccessToken(): Promise<string | null>;
  readRefreshToken(): Promise<string | null>;
  saveTokens(access: string, refresh: string): Promise<void>;
  clear(): Promise<void>;
}

export const tokenStorage: TokenStorage = {
  readAccessToken: () => get(ACCESS_KEY),
  readRefreshToken: () => get(REFRESH_KEY),
  saveTokens: async (access, refresh) => {
    await set(ACCESS_KEY, access);
    await set(REFRESH_KEY, refresh);
  },
  clear: async () => {
    await del(ACCESS_KEY);
    await del(REFRESH_KEY);
  },
};

export const deviceStorage = {
  readDeviceId: () => get(DEVICE_KEY),
  saveDeviceId: (id: string) => set(DEVICE_KEY, id),
};
