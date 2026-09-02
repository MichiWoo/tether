import { reactive } from "vue";

export type ToastKind = "info" | "success" | "error";

export interface Toast {
  id: number;
  message: string;
  kind: ToastKind;
}

export const toasts = reactive<Toast[]>([]);

let seq = 0;

export function showToast(message: string, kind: ToastKind = "info"): void {
  const id = ++seq;
  toasts.push({ id, message, kind });
  setTimeout(() => dismissToast(id), 4000);
}

export function dismissToast(id: number): void {
  const index = toasts.findIndex((t) => t.id === id);
  if (index >= 0) toasts.splice(index, 1);
}
