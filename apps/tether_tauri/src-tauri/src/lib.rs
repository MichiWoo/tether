use futures_util::StreamExt;
#[cfg(desktop)]
use keyring::Entry;
use serde::Serialize;
use tauri::{Emitter, Manager};
#[cfg(desktop)]
use tauri_plugin_autostart::ManagerExt as AutostartManagerExt;
use tauri_plugin_dialog::DialogExt;
use tokio::io::AsyncWriteExt;
use tokio_util::io::ReaderStream;

#[cfg(desktop)]
use tauri::{
    menu::{CheckMenuItem, Menu, MenuItem, PredefinedMenuItem},
    tray::TrayIconBuilder,
};

const KEYRING_SERVICE: &str = "app.tether";

// ─────────────────────────────────────────────────────────────
// Plataforma
// ─────────────────────────────────────────────────────────────

#[tauri::command]
fn platform_info() -> serde_json::Value {
    let os = std::env::consts::OS;
    let is_desktop = matches!(os, "macos" | "windows" | "linux");
    serde_json::json!({ "os": os, "isDesktop": is_desktop })
}

// ─────────────────────────────────────────────────────────────
// Almacenamiento seguro (Keychain / Credential Manager / Secret Service
// en escritorio; archivo privado de la app en móvil, donde no hay
// Secret Service/D-Bus ni Keychain accesible desde Rust).
//
// Nota: `app: AppHandle` lo inyecta Tauri automáticamente, el frontend
// sigue llamando a estos comandos igual que antes.
// ─────────────────────────────────────────────────────────────

#[cfg(desktop)]
#[tauri::command]
fn keyring_get(key: String) -> Result<Option<String>, String> {
    let entry = Entry::new(KEYRING_SERVICE, &key).map_err(|e| e.to_string())?;
    match entry.get_password() {
        Ok(value) => Ok(Some(value)),
        Err(keyring::Error::NoEntry) => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}

#[cfg(desktop)]
#[tauri::command]
fn keyring_set(key: String, value: String) -> Result<(), String> {
    let entry = Entry::new(KEYRING_SERVICE, &key).map_err(|e| e.to_string())?;
    entry.set_password(&value).map_err(|e| e.to_string())
}

#[cfg(desktop)]
#[tauri::command]
fn keyring_delete(key: String) -> Result<(), String> {
    let entry = Entry::new(KEYRING_SERVICE, &key).map_err(|e| e.to_string())?;
    entry.delete_credential().map_err(|e| e.to_string())
}

#[cfg(mobile)]
fn secure_file_path(app: &tauri::AppHandle, key: &str) -> Result<std::path::PathBuf, String> {
    let dir = app.path().app_data_dir().map_err(|e| e.to_string())?;
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let safe: String = key
        .chars()
        .map(|c| if c.is_alphanumeric() { c } else { '_' })
        .collect();
    Ok(dir.join(format!("secure-{safe}.dat")))
}

#[cfg(mobile)]
#[tauri::command]
fn keyring_get(app: tauri::AppHandle, key: String) -> Result<Option<String>, String> {
    let path = secure_file_path(&app, &key)?;
    match std::fs::read_to_string(&path) {
        Ok(value) => Ok(Some(value)),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
        Err(e) => Err(e.to_string()),
    }
}

#[cfg(mobile)]
#[tauri::command]
fn keyring_set(app: tauri::AppHandle, key: String, value: String) -> Result<(), String> {
    let path = secure_file_path(&app, &key)?;
    std::fs::write(&path, value).map_err(|e| e.to_string())
}

#[cfg(mobile)]
#[tauri::command]
fn keyring_delete(app: tauri::AppHandle, key: String) -> Result<(), String> {
    let path = secure_file_path(&app, &key)?;
    match std::fs::remove_file(&path) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(e) => Err(e.to_string()),
    }
}

// ─────────────────────────────────────────────────────────────
// Transferencia de archivos (subida/descarga directa a S3 presignado)
// ─────────────────────────────────────────────────────────────

#[derive(Serialize)]
struct PickedFile {
    name: String,
    path: String,
    size: u64,
}

/// Abre el diálogo de selección de archivos y devuelve metadatos locales.
#[cfg(desktop)]
#[tauri::command]
async fn pick_files(app: tauri::AppHandle) -> Result<Vec<PickedFile>, String> {
    let files = app
        .dialog()
        .file()
        .add_filter("Todos los archivos", &["*"])
        .blocking_pick_files();

    map_picked_files(files)
}

/// En móvil no existen las variantes `blocking_*`: se usa el callback
/// async del plugin dialog convertido a oneshot.
#[cfg(mobile)]
#[tauri::command]
async fn pick_files(app: tauri::AppHandle) -> Result<Vec<PickedFile>, String> {
    let (tx, rx) = tokio::sync::oneshot::channel();
    app.dialog()
        .file()
        .add_filter("Todos los archivos", &["*"])
        .pick_files(move |files| {
            let _ = tx.send(files);
        });
    let files = rx.await.map_err(|e| e.to_string())?;

    map_picked_files(files)
}

fn map_picked_files(files: Option<Vec<tauri_plugin_dialog::FilePath>>) -> Result<Vec<PickedFile>, String> {
    let mut result = Vec::new();
    if let Some(files) = files {
        for file in files {
            let path = match file {
                tauri_plugin_dialog::FilePath::Path(p) => p,
                _ => continue,
            };
            let name = path
                .file_name()
                .map(|s| s.to_string_lossy().to_string())
                .unwrap_or_else(|| "archivo".to_string());
            let size = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
            result.push(PickedFile { name, path: path.to_string_lossy().to_string(), size });
        }
    }
    Ok(result)
}

/// Tamaño en bytes de un archivo local (para drops sin metadata previa).
#[tauri::command]
fn file_size(path: String) -> Result<u64, String> {
    std::fs::metadata(&path)
        .map(|m| m.len())
        .map_err(|e| e.to_string())
}

/// Abre el diálogo "guardar como" y devuelve la ruta elegida (o `None`).
#[cfg(desktop)]
#[tauri::command]
async fn pick_download_path(
    app: tauri::AppHandle,
    suggested_name: String,
) -> Result<Option<String>, String> {
    let res = app
        .dialog()
        .file()
        .set_file_name(&suggested_name)
        .blocking_save_file();
    Ok(res.and_then(|p| p.as_path().map(|p| p.to_string_lossy().to_string())))
}

/// Variante móvil del diálogo "guardar como" (sin `blocking_*`).
#[cfg(mobile)]
#[tauri::command]
async fn pick_download_path(
    app: tauri::AppHandle,
    suggested_name: String,
) -> Result<Option<String>, String> {
    let (tx, rx) = tokio::sync::oneshot::channel();
    app.dialog()
        .file()
        .set_file_name(&suggested_name)
        .save_file(move |res| {
            let _ = tx.send(res);
        });
    let res = rx.await.map_err(|e| e.to_string())?;
    Ok(res.and_then(|p| p.as_path().map(|p| p.to_string_lossy().to_string())))
}

/// Sube un archivo local a una URL presignada (PUT directo a S3/MinIO),
/// reportando progreso vía el evento `upload-progress`.
#[tauri::command]
async fn upload_file(
    app: tauri::AppHandle,
    id: String,
    path: String,
    url: String,
    content_type: String,
) -> Result<(), String> {
    let file = tokio::fs::File::open(&path)
        .await
        .map_err(|e| e.to_string())?;
    let total = file.metadata().await.map_err(|e| e.to_string())?.len();

    let reader = tokio::io::BufReader::new(file);
    let mut sent: u64 = 0;

    let stream = ReaderStream::new(reader).map(move |chunk| {
        let chunk = chunk.map_err(|e| e.to_string())?;
        sent += chunk.len() as u64;
        let _ = app.emit(
            "upload-progress",
            serde_json::json!({ "id": id, "sent": sent, "total": total }),
        );
        Ok::<Vec<u8>, String>(chunk.to_vec())
    });

    let client = reqwest::Client::new();
    let resp = client
        .put(url)
        .header(reqwest::header::CONTENT_TYPE, content_type)
        .header(reqwest::header::CONTENT_LENGTH, total)
        .body(reqwest::Body::wrap_stream(stream))
        .send()
        .await
        .map_err(|e| e.to_string())?;

    if !resp.status().is_success() {
        return Err(format!("El servidor rechazó la subida (HTTP {}).", resp.status().as_u16()));
    }
    Ok(())
}

/// Descarga una URL presignada hacia `save_path`, reportando progreso vía el
/// evento `download-progress`.
#[tauri::command]
async fn download_file(
    app: tauri::AppHandle,
    id: String,
    url: String,
    save_path: String,
) -> Result<(), String> {
    let client = reqwest::Client::new();
    let resp = client.get(url).send().await.map_err(|e| e.to_string())?;

    if !resp.status().is_success() {
        return Err(format!("La descarga falló (HTTP {}).", resp.status().as_u16()));
    }

    let total = resp.content_length().unwrap_or(0);
    let mut file = tokio::fs::File::create(&save_path)
        .await
        .map_err(|e| e.to_string())?;

    let mut stream = resp.bytes_stream();
    let mut received: u64 = 0;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| e.to_string())?;
        received += chunk.len() as u64;
        file.write_all(&chunk).await.map_err(|e| e.to_string())?;
        let _ = app.emit(
            "download-progress",
            serde_json::json!({ "id": id, "received": received, "total": total }),
        );
    }
    Ok(())
}

// ─────────────────────────────────────────────────────────────
// Bandeja del sistema (solo escritorio)
// ─────────────────────────────────────────────────────────────

#[cfg(desktop)]
fn build_tray(app: &tauri::App) -> tauri::Result<()> {
    let autostart_enabled = app.autolaunch().is_enabled().unwrap_or(false);

    let show = MenuItem::with_id(app, "show", "Mostrar Tether", true, None::<&str>)?;
    let autostart = CheckMenuItem::with_id(
        app,
        "autostart",
        "Abrir al iniciar sesión",
        true,
        autostart_enabled,
        None::<&str>,
    )?;
    let quit = MenuItem::with_id(app, "quit", "Salir", true, None::<&str>)?;
    let sep = PredefinedMenuItem::separator(app)?;
    let menu = Menu::with_items(app, &[&show, &autostart, &sep, &quit])?;

    let mut tray = TrayIconBuilder::new()
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id.as_ref() {
            "show" => {
                if let Some(w) = app.get_webview_window("main") {
                    let _ = w.show();
                    let _ = w.set_focus();
                }
            }
            "autostart" => {
                let autostart = app.autolaunch();
                match autostart.is_enabled() {
                    Ok(true) => {
                        let _ = autostart.disable();
                    }
                    Ok(false) => {
                        let _ = autostart.enable();
                    }
                    Err(_) => {}
                }
            }
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let tauri::tray::TrayIconEvent::Click { .. } = event {
                let app = tray.app_handle();
                if let Some(w) = app.get_webview_window("main") {
                    let _ = w.show();
                    let _ = w.set_focus();
                }
            }
        });

    if let Some(icon) = app.default_window_icon().cloned() {
        tray = tray.icon(icon);
    }

    tray.build(app)?;

    Ok(())
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default()
        .plugin(tauri_plugin_clipboard_manager::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_process::init());

    // Autostart y updater solo existen en escritorio: en móvil el crate de
    // autostart está vacío (`#![cfg(not(mobile))]`) y las stores gestionan
    // las actualizaciones. El frontend ya tolera el error del updater.
    #[cfg(desktop)]
    let builder = builder
        .plugin(tauri_plugin_autostart::init(
            tauri_plugin_autostart::MacosLauncher::LaunchAgent,
            None,
        ))
        .plugin(tauri_plugin_updater::Builder::new().build());

    builder
        .invoke_handler(tauri::generate_handler![
            platform_info,
            keyring_get,
            keyring_set,
            keyring_delete,
            pick_files,
            pick_download_path,
            file_size,
            upload_file,
            download_file,
        ])
        .setup(|app| {
            #[cfg(desktop)]
            build_tray(app)?;
            Ok(())
        })
        .on_window_event(|window, event| {
            // Minimizar a bandeja al cerrar la ventana (solo escritorio).
            #[cfg(desktop)]
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }

            // Archivos soltados sobre la ventana → reemitir con rutas al frontend.
            #[cfg(desktop)]
            {
                if let tauri::WindowEvent::DragDrop(tauri::DragDropEvent::Enter { .. }) = event {
                    let _ = window.emit("file-drop-enter", true);
                }
                if let tauri::WindowEvent::DragDrop(tauri::DragDropEvent::Leave) = event {
                    let _ = window.emit("file-drop-enter", false);
                }
                if let tauri::WindowEvent::DragDrop(tauri::DragDropEvent::Drop { paths, .. }) = event {
                    let _ = window.emit("file-drop", serde_json::json!({ "paths": paths }));
                    let _ = window.emit("file-drop-enter", false);
                }
            }
        })
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
