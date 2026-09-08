import { check } from "@tauri-apps/plugin-updater";
import { relaunch } from "@tauri-apps/plugin-process";

export interface UpdateState {
  status: "idle" | "checking" | "available" | "downloading" | "upToDate" | "error";
  version?: string;
  notes?: string;
  error?: string;
}

let onState: ((state: UpdateState) => void) | null = null;

export function subscribeUpdater(cb: (state: UpdateState) => void): () => void {
  onState = cb;
  return () => {
    onState = null;
  };
}

function emit(state: UpdateState) {
  onState?.(state);
}

export async function checkForUpdates(): Promise<UpdateState> {
  emit({ status: "checking" });
  try {
    const update = await check();
    if (!update) {
      const state = { status: "upToDate" as const };
      emit(state);
      return state;
    }
    const state = {
      status: "available" as const,
      version: update.version,
      notes: update.body,
    };
    emit(state);
    return state;
  } catch (err) {
    const state: UpdateState = {
      status: "error",
      error: err instanceof Error ? err.message : String(err),
    };
    emit(state);
    return state;
  }
}

export async function installUpdate(): Promise<UpdateState> {
  emit({ status: "downloading" });
  try {
    const update = await check();
    if (!update) {
      const state = { status: "upToDate" as const };
      emit(state);
      return state;
    }
    await update.downloadAndInstall();
    await relaunch();
    return { status: "idle" };
  } catch (err) {
    const state: UpdateState = {
      status: "error",
      error: err instanceof Error ? err.message : String(err),
    };
    emit(state);
    return state;
  }
}
