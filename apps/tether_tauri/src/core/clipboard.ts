import { writeText } from "@tauri-apps/plugin-clipboard-manager";

// Escribe texto en el portapapeles del sistema. Devuelve `false` si falla.
export async function writeClipboard(text: string): Promise<boolean> {
  try {
    await writeText(text);
    return true;
  } catch {
    return false;
  }
}
