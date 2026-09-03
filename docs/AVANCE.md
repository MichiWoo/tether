# Tether — Avance del proyecto

Este documento registra el estado actual del proyecto y lo que queda pendiente. Se actualiza al cierre de cada sesión.

> **Última actualización:** 03/09/2026 (cliente Tauri + Vue: tema Dracula en modo oscuro y dashboard de inicio con `GET /stats`)

## Estado general

| Fase | Backend | App Flutter | Estado |
|---|---|---|---|
| **1. MVP (cloud)** | Completado | Iteración 8 (mobile Android) | En desarrollo |
| 2. P2P LAN | — | — | Pendiente |
| 3. Sin internet (Bluetooth) | — | — | Pendiente |
| 4. Monetización | — | — | Pendiente |

## 1. Backend — Fase 1 MVP (completado)

Monorepo pnpm con **NestJS 11** (TypeScript estricto, ESM) en `apps/backend`.

### Módulos

| Módulo | Alcance | Estado |
|---|---|---|
| **Auth** | registro/login, JWT access + refresh rotativo con **reuse detection** (revoca todos), logout | ✅ |
| **Devices** | CRUD de dispositivos propios, estado online/offline (heartbeat + WebSocket) | ✅ |
| **Clipboard** | push/pull de texto, historial, dedupe por `contentHash` (unique index + catch P2002) | ✅ |
| **Files** | presigned URLs S3/MinIO (upload/descarga directa cliente↔S3), `complete` verifica en S3, TTL | ✅ || **Realtime** | Gateway Socket.IO en `/realtime`, auth JWT en handshake, rooms por usuario/device, eventos en vivo | ✅ |
| **Transfers** | shares de archivos con **BullMQ** (cola `transfers`), eventos `share.*`, TTL de expiración que limpia S3 | ✅ |
| **Storage** | Cliente S3/MinIO (global), bucket auto-creado, presigned URLs | ✅ |
| **Health** | `/health` con checks de dependencias (`database`, `redis`, `storage`) | ✅ |

### Calidad y seguridad

- **Validación de env fail-fast (Joi)** — arranque falla listando todos los errores; secrets obligatorios (≥32 chars).
- **Rate limiting** (`@nestjs/throttler`) — global 100 req/min; auth estricto (register 5/min, login 10/min, refresh 30/min → `429` + `Retry-After`).
- **CORS por lista blanca** (`CORS_ORIGINS`) y **helmet** en HTTP y WebSocket.
- **Transacciones** — refresh rotation atómica (`$transaction`) y dedupe de clipboard con unique index.
- **TypeScript estricto** — `strict`, `noUnusedLocals`, `verbatimModuleSyntax` (imports de tipos con `import type`).
- **Logging estructurado (pino)** — pretty en dev, JSON en QA/prod (`LOG_LEVEL`), request logs.
- **Exception filter global** — errores unificados `{ statusCode, message, error, path, timestamp }`.
- **Swagger/OpenAPI** — plugin CLI + DTOs de respuesta como classes (18 schemas), UI en `/docs`.

### Tests

- **Vitest + SWC + Supertest**: **27 tests** (24 unit + 3 e2e) sobre auth, clipboard, files y transfers.

### Infraestructura de dev

`docker-compose.yml`: Postgres 16 (`:5434`), Redis 7 (`:6379`), MinIO (`:9002` S3 / `:9001` consola). La API corre en `:3100`.

> **Fix (12/08/2026):** MinIO se movió de `:9000` a `:9002` porque el `:9000` estaba ocupado por php-fpm en el loopback IPv4 (`127.0.0.1:9000`), lo que hacía que el PUT presignado del app fallara con "Error de red al subir" cuando resolvía `localhost` por IPv4. También se mejoró el mensaje de error de subida en la app para distinguir conexión vs firma (403) vs otros HTTP.

> **Key de S3 (12/08/2026):** ahora incluye el nombre del archivo para que sea reconocible en la consola de MinIO: `users/{userId}/{fileId}/{nombre-sanitizado}` (ej. `.../foto.jpg`). Antes era solo `users/{userId}/{fileId}`. Los objetos existentes se migraron; el nombre real sigue viviendo en la BD (`files.name`), y la descarga usa `Content-Disposition`.

### Enlaces

- [`README.md`](../README.md) — visión, quick start, ambientes, endpoints y flujos end-to-end.
- [`API.md`](API.md) — API completa, ambientes (dev/QA/prod) y eventos WebSocket.
- [`ROADMAP.md`](ROADMAP.md) — visión y fases.

## 2. App Flutter — iteración 1 base desktop (completada)

`apps/tether_app` — un solo proyecto multi-target (macos, windows, linux, ios, android, web). Foco actual: **macOS**.

### Lo incluido

- **Riverpod** + **Dio** con interceptor JWT (Bearer + refresh rotativo en 401) + **flutter_secure_storage** (keychain).
- **Auth**: pantalla login/registro con validación y errores amigables, `AuthNotifier` con bootstrap/restore de sesión.
- **Realtime**: `RealtimeService` (Socket.IO `/realtime`, auto-reconnect) con badge de conexión.
- **Shell**: `NavigationRail` (Dispositivos · Portapapeles · Archivos) con placeholders, topbar con tema claro/oscuro y menú de cuenta.
- **Tema Material 3** light/dark, tipografía Inter, ventana configurada con `window_manager`.
- **macOS**: entitlements de red (`network.client`) en Debug y Release.
- Verificado: `flutter analyze`, `flutter test`, `flutter build macos --debug`, `flutter run -d macos` contra el backend local.

## 2b. App Flutter — revisión de auth y iteración 2 (completada)

### Revisión de login/register vs buenas prácticas (correcciones aplicadas)

- **Providers de infraestructura movidos a `core/`**: `apiClientProvider` en `core/api/api_provider.dart` y `tokenStorageProvider` en `core/storage/storage_providers.dart` (antes vivían en `features/auth/providers`).
- **`auth_screen.dart`**: eliminado el `setState(() {})` innecesario y el retorno `bool` de login/register; el widget reacciona vía `ref.watch`. Se limpia error/campos al cambiar de modo login↔register.
- **Bootstrap resiliente**: error de red distingue de 401 real → nuevo estado `AuthStatus.offline` conserva la sesión guardada y ofrece "Reintentar conexión"; solo un 401 limpia tokens.
- **Interceptor de refresh mejorado**: requests paralelas en 401 esperan el mismo refresh en curso (future compartido) y se reintentan; si el refresh falla se limpia la sesión. Match exacto de ruta de refresh (sin `path.contains`).
- **Tests de auth**: 14 unit tests (controller, interceptor, restauración de sesión).

### Iteración 2 — Devices y Clipboard

- **Devices**: lista con badge online/offline (actualizada en vivo por `device.online`/`device.offline`), registro, renombrar y eliminar. **Auto-registro del equipo actual** al autenticarse (`POST /devices` con platform detectada, guarda `deviceId` en `DeviceStorage` y emite `device:identify` al WebSocket).
- **Clipboard**: historial, envío de texto (`POST /clipboard` con `sourceDeviceId` = equipo local), updates en vivo por `clipboard.updated`, y botón copiar con **`super_clipboard`**.
- **`RealtimeService`**: `identify(deviceId)`, suscripciones tipadas por evento con cancelación (`onEvent`).
- **Infraestructura**: `DeviceStorage` (keychain), `Endpoints` ampliado.
- **Tests**: 39 totales (14 auth + 10 unit de controllers + 12 widget + 3 base) — controllers de Devices/Clipboard y widget tests de ambas pantallas.
- Verificado: `flutter analyze`, `flutter test`, `flutter build macos --debug`.

## 2c. App Flutter — iteración 3 Files y Compartidos (completada)

### Files (pestaña "Mis archivos")

- **Drag & drop** con `desktop_drop` (overlay "Suelta para subir") y **picker** con `file_selector` (todos los archivos).
- **Upload directo a S3/MinIO con presigned PUT** (`UploadService`, dio sin auth): `POST /files` → PUT a la URL firmada con `Content-Type` exacto y `Content-Length` → `POST /files/:id/complete`.
- **Progreso en vivo** por archivo (barra en cada tarea), errores por archivo con opción de descartar, límite de 2 GB, detección de mime con `mime` (fallback `application/octet-stream`).
- **Lista de archivos** con icono por tipo, tamaño, estado (Pendiente/Listo via `file:ready` en vivo) y acciones compartir/descargar/eliminar.
- **Descarga** con `getSaveLocation` (diálogo "guardar como") vía presigned GET, con avisos de progreso/éxito/error.

### Compartidos (pestaña "Compartidos")

- **Respuesta del backend enriquecida con `senderDeviceId`** (DTO + migración `add_share_sender_device` + columnas/tablas nuevas) para distinguir **Recibidos vs Enviados** en el cliente.
- **Recibidos**: aceptar (`POST /shares/:id/accept`) y descargar (`GET /shares/:id` presigned → descarga → `POST /shares/:id/downloaded`), con estados visible.
- **Enviados**: estado del share (Pendiente → Aceptado/Descargado) y cancelar (`POST /shares/:id/cancel`).
- **Crear share** desde un archivo: diálogo con "Todos los dispositivos" (broadcast) o un device destino; envía `senderDeviceId` = equipo local.
- **Eventos en vivo**: `share.created/accepted/downloaded/expired` mantienen la pestaña al día en todos los dispositivos (dedupe por id).

### Calidad

- `flutter analyze` limpio y `flutter test`: **64 tests** (14 auth + controllers + widget de archivos/compartidos + dispositivos + portapapeles + base).
- `flutter build macos --debug` OK; entitlements macOS incluyen `files.user-selected.read-write` y `files.downloads.read-write`.
- **Smoke test end-to-end real** contra backend local: register → device → create file → PUT MinIO (200) → complete (UPLOADED) → descarga idéntica → share broadcast + dirigido con `senderDeviceId` correcto → accept → downloaded → listado con el campo nuevo.
- Backend: build, lint y **27 tests** OK tras la migración.

## 2d. App Flutter — iteración 4 cola de descargas (completada)

### Descargas con progreso y cola

- **`DownloadsController`** (`providers/downloads_provider.dart`): estado con `List<DownloadTask>`; `start()` lanza descargas **en paralelo** (barra por archivo), `cancel()` usa `CancelToken` y `dismiss()` descarta errores.
- **`UploadService.download`** ahora acepta `cancelToken` y `onProgress` (antes solo existía el parámetro de progreso sin usar).
- **UI**: sección `_DownloadsSection` sobre el `TabBar` de Archivos — visible desde ambas pestañas (Mis archivos y Compartidos) — con `_DownloadTile` (barra `LinearProgressIndicator`, ✕ para cancelar en curso o descartar errores), mismo estilo que `_UploadTile`.
- **Mis archivos**: `_download` ya no usa snackbar para progreso; delega en `DownloadsController.start` y avisa solo en error.
- **Compartidos**: mismo flujo vía `DownloadsController`; al éxito se preserva `markDownloaded(share.id)`.

### Calidad

- `flutter analyze` limpio y `flutter test`: **70 tests** (+6 de `DownloadsController`: inicio/progreso/remoción, error, cancel, dismiss y descargas en paralelo).
- `flutter build macos --debug` OK.

## 2e. App Flutter — iteración 5 auto-copiado de portapapeles (completada)

### Auto-copiar en el dispositivo destino

- **`ClipboardWriter`** (`data/clipboard_writer.dart`): abstracción de `super_clipboard` con `writeText()` que devuelve `bool` sin lanzar (inyectable/fake-able).
- **`ClipboardController`** ahora inyecta `DeviceStorage` y `ClipboardWriter`. Al recibir `clipboard.updated`, **auto-copia** el contenido **solo si viene de otro dispositivo** (compara `sourceDeviceId` con el `deviceId` local, evitando el eco del emisor).
- **`ClipboardState.autoCopiedItem`** + `clearAutoCopied()`: aviso para la UI; la pantalla lo detecta con `ref.listen` y muestra "Copiado de {device}".
- **`ClipboardScreen`**: el copiado manual (`_copy`) reutiliza `ClipboardWriter` (antes duplicaba la lógica de `super_clipboard`).

### Calidad

- `flutter analyze` limpio y `flutter test`: **73 tests** (+3 del auto-copiado: copia de otro device, ignora el propio, `clearAutoCopied`).
- `flutter build macos --debug` OK.

## 2f. App Flutter — iteración 6 tray + autostart (completada)

### Icono de bandeja + minimizar a bandeja + arrancar al iniciar sesión

- **`TrayService`** (`core/tray/tray_service.dart`): inicializa el icono de bandeja (`tray_manager`, icono template `assets/tray_icon.png`), menú contextual **Mostrar / Abrir al iniciar sesión (checkbox) / Salir**, y `setPreventClose(true)` para **minimizar a bandeja** al cerrar la ventana (`onWindowClose` → `hide`). `buildTrayMenu` es una función pura testeable.
- **`AutostartService`** (`core/autostart/autostart_service.dart`): canal nativo `tether/autostart` implementado en `MainFlutterWindow.swift` (LaunchAgent en `~/Library/LaunchAgents/com.tether.app.plist`). **Sin dependencias de Swift Package Manager** (se descartó `launch_at_startup` porque requiere agregar `LaunchAtLogin` por Xcode).
- **`AppDelegate.swift`**: `applicationShouldTerminateAfterLastWindowClosed` → `false` para que la app siga viva en bandeja.
- **`main.dart`**: inicializa `TrayService` solo en desktop.

### Calidad

- `flutter analyze` limpio y `flutter test`: **76 tests** (+3 de `buildTrayMenu`: estructura, estado del checkbox, callbacks).
- `flutter build macos --debug` OK (compila el Swift nativo y registra `tray_manager`).
- Pendiente de verificación en runtime (requiere GUI): icono de bandeja visible y autostart real tras reiniciar sesión.

## 2g. App Flutter — vista previa de archivos (completada)

### Preview de imágenes y texto (clic en el archivo)

- **Backend**: `GET /files/:id/preview` devuelve presigned URL con `Content-Disposition: inline` (nuevo parámetro `disposition` en `StorageService.getPresignedDownloadUrl`; `FilesService.getPreview` reusa la lógica de `getDownload`).
- **App**: `showFilePreview` + `FilePreviewDialog` (`file_preview.dart`) — diálogo modal al hacer clic en el tile:
  - **Imágenes** (`image/*`): `Image.network` con loading/error.
  - **Texto** (`text/*`, JSON, XML, JS, etc.): `UploadService.fetchText` y panel con scroll + `SelectableText` mono.
  - **Otros** (pdf/video/audio): metadata (tamaño, tipo, fecha).
- `FilesApi.getPreviewUrl` / `FilesRepository` / `FilesController.getPreviewUrl` + endpoint `filePreview`.
- `_FileTile` gana `onTap` → preview (solo archivos subidos), sin romper las acciones existentes.

### Calidad

- Backend: **36 tests** (+2 de `getPreview`) y lint/build OK.
- App: `flutter analyze` limpio y `flutter test`: **80 tests** (+4 de `file_preview`: clasificación, texto, error, metadata).
- `flutter build macos --debug` OK.

## 2h. App Flutter — paleta Dracula (completada)

### Tema Dracula Classic (dark) + Alucard Classic (light)

- **`core/theme/dracula_palette.dart`**: constantes exactas del spec de Dracula (`https://draculatheme.com/spec`) + `buildDraculaColorScheme()` (dark) y `buildAlucardColorScheme()` (light) como `ColorScheme` Material 3. Containers derivados por `Color.alphaBlend` sobre el fondo.
- **`core/theme/app_theme.dart`**: tema oscuro = Dracula Classic, tema claro = Alucard Classic (primario púrpura `#BD93F9`); conserva Inter y Material 3.
- **Indicadores de estado theme-aware** (`StatusColors.success/info/warning/danger`): badge de conexión en `home_shell`, estados de share en `shares_section`, dot online en `_ShareDialog` y badge "En línea" en `devices_screen` (antes `Colors.green/blue/amber`).

### Calidad

- `flutter analyze` limpio, `flutter test` **80 tests** OK, `flutter build macos --debug` OK.

## 2i. App Flutter — upgrade SDK + pilot shadcn_flutter (completada)

### Upgrade de Flutter 3.24.2 → 3.47.0 (Dart 3.9)

- `flutter upgrade` a stable 3.47.0. Se corrigieron deprecaciones (`withOpacity` → `withValues`) y se actualizó `google_fonts` a `^8.2.1` (la 6.3.0 rompía compilación de tests con el Dart nuevo). `flutter clean` para regenerar el caché de módulos Swift de pods.

### Pilot shadcn_flutter

- **`shadcn_flutter 0.0.53`** instalado (84 componentes, estilo shadcn/ui "New York").
- **`core/theme/shadcn_theme.dart`**: `buildShadcnTheme(Brightness)` con `ColorScheme` shadcn a partir de la paleta Dracula (dark) / Alucard (light) + widget `TetherShadcnTheme`.
- **`app.dart`**: se envuelve el `MaterialApp` (vía `builder`) con `TetherShadcnTheme`, para que los componentes shadcn tengan tema sin chocar con Material (la librería redefine `Theme`/`ThemeData`/`Text`/`Button`, etc.).
- **Migraciones aplicadas** (interop: reescrituras completas + imports prefijados `as shadcn` para mezclar sin colisiones):
  - **`file_preview.dart`** (diálogo de vista previa): `Card`, `Button`, `Icon`, `Text`, progreso shadcn. `_preview` en `files_screen` resuelve la URL y lo muestra.
  - **`auth_screen.dart`** (rewrite completo shadcn): `TextField`, `Button.primary/secondary/ghost`, `Card`; validación manual; mantiene los textos de `widget_test`.
  - **`clipboard_screen.dart`**: campo de envío → `shadcn.TextField` + `shadcn.Button.primary` (key `clipboard-input`).
  - **`files_screen.dart` / `shares_section.dart`**: iconos de acción → `shadcn.IconButton.ghost`; botones de diálogos (eliminar/compartir) → `shadcn.Button.ghost/destructive`; "Aceptar" → `shadcn.Button.secondary`.
  - **`devices_screen.dart`**: botones "Registrar"/"Guardar" → `shadcn.Button.primary`, "Cancelar" → `shadcn.Button.ghost`, "Eliminar" → `shadcn.Button.destructive`.
  - **`home_shell.dart`**: toggle de tema y avatar → `shadcn.IconButton.ghost`.

### Calidad / estado

- `flutter analyze` limpio, **80 tests** OK (los tests de `file_preview`, `clipboard`, `files_screen` y `devices` envuelven `TetherShadcnTheme`), `flutter build macos --debug` OK.
- **Pendiente**: el shell (`NavigationRail`), tabs de Archivos y listas (`ListTile`) siguen Material; se pueden migrar a shadcn (`Tabs`/`NavigationMenu`/`Card`) en una siguiente tanda. Nota: `flutter doctor` reporta que falta Android SDK 36 (no bloquea el foco macOS).

## 2j. App Flutter — identidad visual + migración completa a shadcn_flutter (completada)

### Rediseño con identidad "Constellation" (Tether = el hilo que conecta dispositivos)

- **Tipografía** (`core/theme/app_typography.dart`): **Sora** (display/body) + **JetBrains Mono** (IDs, fechas, tamaños, conteos, etiquetas de plataforma). Aplicada tanto al tema Material (`app_theme.dart`) como al de shadcn (`Typography.geist` con `sans`/`mono` custom).
- **Auth** (`auth_screen.dart` reescrito): fondo de constelación animada (nodos + señal que recorre el grafo, fade-in de 3s que respeta `MediaQuery.disableAnimations`), tarjeta con glow, marca con logo en aro, toggle segmentado Iniciar/Crear cuenta, campos con icono `leading`, `autofocus`, autofill, `InputFeature.passwordToggle()` integrado y errores con `Semantics` (live region).
- **Shell** (`home_shell.dart`): sidebar propia (marca + `StatusChip` de realtime + items con indicador activo) en lugar de `NavigationRail`; menú de cuenta shadcn.

### Migración a shadcn del resto de la UI

- **Widgets compartidos** (`core/widgets/`): `CardTile` (reemplazo de `ListTile` con hover), `TetherDialog` (diálogo con cuerpo `Card`), `ErrorBanner`, `EmptyState`, `StatusChip`.
- **`files_screen.dart`**: `TabBar`/`TabBarView` → `shadcn.Tabs` + `TabItem`; listas → `CardTile`; `FilledButton.tonal` → `Button.secondary`; `AlertDialog` → `TetherDialog`; `LinearProgressIndicator` → `shadcn.LinearProgressIndicator`.
- **`shares_section.dart`**: `SegmentedButton` → toggle segmentado; `ListTile` → `CardTile`.
- **`devices_screen.dart`**: `PopupMenuButton` → `shadcn.showDropdown` + `DropdownMenu`; `ListTile`/`CircleAvatar` → `CardTile` + contenedor redondeado; `AlertDialog`/`TextField` → `TetherDialog` + `shadcn.TextField` (key `name-input`).
- **`clipboard_screen.dart`**: `ListTile` → `CardTile`.
- **`shadcn_theme.dart`**: se añade `OverlayManagerLayer` (menús/popovers/tooltips shadcn) sobre el `Theme`.
- **Assets**: `logo.png` optimizado (1254×1254 ~1.1 MB → 256×256 ~77 KB).

### Calidad / estado

- `flutter analyze` limpio, `flutter test` **80 tests** OK (se ajustaron `devices_screen_test` — `find.byIcon(Icons.more_horiz)` y `Key('name-input')` — y `files_screen_test` — `shadcn.LinearProgressIndicator`), `flutter build macos --debug` OK.
- **Sigue Material** (transitorio, sin impacto visual fuerte): `RefreshIndicator` (pull-to-refresh) y `CircularProgressIndicator` de carga.

## 2k. App Flutter — iteración 8 Mobile Android (primera pasada, mínima viable)

### Entorno Android (desbloqueo)

- Instalado **Android SDK Platform 36 + Build-Tools 28.0.3/36** (`sdkmanager`) y aceptadas licencias (`flutter doctor` en verde).
- **JDK 17** instalado vía Homebrew (`openjdk@17`) y configurado con `flutter config --jdk-dir` + `JAVA_HOME` en `.zshrc`. El JBR de Android Studio es Java 25, incompatible con Gradle 8.x (por eso fallaba el build).
- **Android Gradle actualizado** al stack que soporta Flutter 3.47 sin romper plugins Rust (`super_clipboard` → `super_native_extensions` → `irondash_engine_context`/CargoKit): `settings.gradle.kts` + `build.gradle.kts` + `app/build.gradle.kts` (Kotlin DSL), **Gradle 8.14**, **AGP 8.11.1**, **Kotlin 2.2.20**. (AGP 9.1/Gradle 9.3, el default de la plantilla, rompe CargoKit porque `Project.exec()` se eliminó en Gradle 9.)

### Adaptación mobile (sin romper desktop)

- **`core/platform/platform_info.dart`**: `isDesktop` / `isMobile` / `isAndroid`; `main.dart` reutiliza el helper (window/tray solo en desktop).
- **`files_screen.dart`**: `DropTarget` (drag & drop) ahora solo se monta en desktop (`if (isDesktop)`); en mobile queda el picker `file_selector.openFiles`.
- **`home_shell.dart`**: shell responsive — en `isMobile` se usa `NavigationBar` inferior con las 3 secciones (en vez de la `_Sidebar` fija), reutilizando `_Section`.
- **Descargas en Android**: `features/files/data/download_path.dart` (`resolveDownloadPath` + `persistDownload`) — Android no tiene escritura directa a carpetas públicas (scoped storage), así que descarga a un temporal (`getTemporaryDirectory`) y luego abre el diálogo **"guardar como" (SAF)** con `flutter_file_dialog` para que el usuario elija dónde; muestra snackbar con la ruta. Desktop/iOS siguen con `getSaveLocation`.
- **Config nativa**: `AndroidManifest.xml` (`INTERNET` + `usesCleartextTraffic` + label "Tether"); `Info.plist` (`NSAllowsLocalNetworking` para http://localhost en dev).

### Fix descarga en emulador (URL S3)

- **Problema**: la presigned URL de MinIO apuntaba a `http://localhost:9002`, que desde el emulador es el propio emulador (no el Mac) → `Error de red al descargar`.
- **Fix**: `MINIO_ENDPOINT=localhost` → `MINIO_ENDPOINT=192.168.1.69` (IP LAN del Mac) en `apps/backend/.env` + reiniciar el backend. La presigned URL ahora usa `192.168.1.69:9002`, alcanzable desde el emulador y desde desktop. (No se puede reescribir `localhost→10.0.2.2` en la app porque la firma SigV4 incluye el host.)
- **Debug**: añadido `debugPrint` de la excepción real en `downloads_provider.dart` (antes se tragaba en catches genéricos).

## 2l. Iconos de la app (logo Tether)

- **`scripts/generate_icons.py`** (Pillow, ya disponible): genera todos los iconos desde `assets/icon_source.png` (logo 1254×1254) con ~6% de margen y fondo transparente.
- Generados: **macOS Dock** (`AppIcon.appiconset/app_icon_16..1024`), **Android launcher** (`mipmap-*/ic_launcher` 48–192), **iOS** (`AppIcon.appiconset` completo) y **tray/menú** (`assets/tray_icon.png` como silueta monocroma template).
- Reemplaza los iconos por defecto de Flutter. Re-ejecutar con `python3 scripts/generate_icons.py` al cambiar el logo.
- Nota: macOS cachea el icono del Dock/Finder; si no refresca, `killall Dock` y `killall Finder`.

### Calidad / estado

- `flutter analyze` limpio, `flutter test` **80 tests** OK, `flutter build apk --debug` **OK** (`app-debug.apk`), `flutter build macos --debug` OK (desktop no regresionó).
- **Restricciones mobile** (a documentar/handled): sin tray, sin autostart, sin monitoreo de portapapeles en background; subida/descarga en foreground.
- **Pendiente mobile**: recibir shares (`receive_sharing_intent`) y compartir (`share_plus`), y validación de iOS en device real. Nota: desde el emulador Android usar `--dart-define=API_BASE_URL=http://10.0.2.2:3100` (en el simulador iOS `localhost` apunta al Mac directamente). Riesgo: la IP LAN (`192.168.1.69`) es por DHCP — si cambia, actualizar `.env`.

## 2m. App Flutter — iOS (primera pasada)

- **`flutter build ios --simulator --debug` OK** y app corriendo en el simulador (iPhone 16 Pro). Flutter 3.47 aplicó la migración automática a **UIScene lifecycle** (`AppDelegate.swift`, `Info.plist` con `UIApplicationSceneManifest`, `Podfile`, `project.pbxproj`, `AppFrameworkInfo.plist`, min iOS 15) — commiteada.
- Sin código nuevo: el soporte mobile ya era genérico (`isMobile`/`isAndroid`, `SafeArea`, shell con `NavigationBar`).
- **Fix descargas iOS**: `file_selector.getSaveLocation` no está implementado en iOS (`UnimplementedError`). Se unificó a `isMobile`: descarga a temporal + `flutter_file_dialog.saveFile` (document picker en iOS / SAF en Android); solo desktop usa `getSaveLocation`.
- Nota: los plugins `device_info_plus`, `flutter_secure_storage`, `irondash_engine_context` y `super_native_extensions` aún usan CocoaPods (aviso de SPM, no bloquea).

## 2n. App Flutter — compartir y recibir con otras apps (mobile)

### Compartir hacia otras apps (`share_plus`)

- **`share_plus 12.0.2`** (la 13.x requiere `win32 ^6`, incompatible con `flutter_secure_storage` 9.x que pide `win32 ^5`).
- **`ShareService`** (`features/files/data/share_service.dart`): abstracción de `SharePlus.instance.share(ShareParams(...))` con `shareFile`/`shareText`, override-able en tests.
- **`files_screen.dart`**: el icono `ios_share` de cada archivo ahora abre un menú shadcn (`showDropdown`/`DropdownMenu`) con **"Con un dispositivo"** (diálogo de share existente) y **"En otra app"** (descarga a temporal + `shareFile`). Snackbar en error.
- `download_path.dart`: nuevo `resolveTempDownloadPath` (temporal en cualquier plataforma).

### Recibir de otras apps (`receive_sharing_intent`, Android)

- **`receive_sharing_intent 1.8.1`** (pin exacto: la 1.9.0 exige `compileSdk 37` + AGP 9.x, incompatible con el stack AGP 8.11.1/Gradle 8.14 del proyecto; además es SPM-only en iOS).
- **`ReceiveSharingService`** (`core/sharing/receive_sharing_service.dart`): wrapper inyectable de `ReceiveSharingIntent` (`getMediaStream`, `getInitialMedia`, `reset`).
- **`IncomingSharesController`** (`core/sharing/incoming_shares_provider.dart`): procesa media entrante — texto/URL → `clipboard.push` (con `sourceDeviceId` local); archivos/imágenes/videos → `files.uploadPaths` + navega a Archivos. `start()` consume el intent inicial (cold start) y suscribe al stream; `stop()` al cerrar sesión.
- **`app.dart`**: `_IncomingSharesBootstrap` orquesta `start()`/`stop()` según `AuthStatus` (cola el intent inicial hasta autenticar).
- **`core/navigation/home_section.dart`**: `HomeSection` + `homeSectionProvider` (StateProvider) — el shell ya no usa `_section` local; permite saltar a "Archivos" al recibir.
- **`AndroidManifest.xml`**: `intent-filter`s `SEND`/`SEND_MULTIPLE` para `text/*`, `image/*`, `video/*`, `*/*` y `launchMode="singleTask"`.
- **`android/build.gradle.kts`**: alineación de `compileOptions` a Java 17 para `receive_sharing_intent` (sin `compileOptions` en el plugin → error "Inconsistent JVM-target compatibility" Java 1.8 vs Kotlin 17).

### Calidad / estado

- `flutter analyze` limpio, `flutter test` **87 tests** (+6 de `IncomingSharesController` +1 widget del menú compartir), `flutter build apk --debug` OK, `flutter build ios --simulator --debug` OK, `flutter build macos --debug` OK (desktop no regresionó).
- **iOS recibir pendiente**: requiere Share Extension + Swift Package Manager + App Groups (firma), paso manual en Xcode. En iOS hoy funciona compartir (share_plus) pero no recibir.
- Restricción mobile documentada: el plugin no corre en background; el share entrante se procesa al abrir la app.

## 2o. Cliente Tauri + Vue — tema Dracula y dashboard de inicio (completada)

`apps/tether_tauri` — cliente de escritorio **Tauri 2 + Vue 3** (TypeScript, Tailwind, Pinia). Es el cliente de diseño actual (lenguaje "one-bit"); el Flutter queda como referencia funcional.

### Identidad visual "one-bit"

- Lenguaje de "escritorio de un solo bit" (Mac clásico): tinta/papel, **dither ordenado** como único gris, sombras duras sin blur, esquinas 0px, tipografía pixel **Silkscreen** (títulos) + **JetBrains Mono** (datos) + system-ui (body). Documentado en `apps/tether_tauri/DESIGN.md` y `PRODUCT.md`.
- Todos los colores fluyen por 4 variables CSS (`--ink`, `--paper`, `--muted`, `--gray-2`) en `src/styles.css`, con modo claro/oscuro que las invierte (`src/core/theme.ts`).

### Tema Dracula (solo colores base)

- Modo oscuro recoloreado a la paleta base de **Dracula** (sin acentos, respetando la regla de dos colores): fondo `#282a36` (`--paper`), tinta `#f8f8f2` (`--ink`), texto secundario `#6272a4` (`--muted`), hover `#44475a` (`--gray-2`). El modo claro queda intacto (negro sobre blanco).
- Dither, sombras duras, stripes y el fondo de constelación leen `rgb(var(--ink))`/`rgb(var(--paper))`, así que se recolorean automáticamente.

### Dashboard de inicio

- Nueva sección **"Inicio"** como primer ítem del menú y **pantalla por defecto** (`src/stores/ui.ts`, `HomeShell.vue`).
- `src/features/dashboard/DashboardScreen.vue`: héroe "Datos transferidos" (MB/GB) + 4 conteos (archivos subidos, compartidos, dispositivos, portapapeles), en el lenguaje one-bit.
- `src/stores/stats.ts` consume `GET /stats`; endpoint y tipo `Stats` añadidos a `core/http.ts` y `core/types.ts`.

### Backend — módulo `stats`

- Nuevo módulo `apps/backend/src/stats/` (`GET /stats`): agrega con Prisma `count`/`aggregate` (suma de `size`) sobre archivos UPLOADED, shares, dispositivos y portapapeles. Registrado en `app.module.ts`; documentado en `docs/API.md` y `README.md`.

### Calidad / estado

- Backend: `nest build` + `eslint` OK. App: `vue-tsc --noEmit` y `vite build` OK.
- Prerrequisito de la app: Rust + dependencias de Tauri; `pnpm --filter @tether/app-tauri dev` (o `dev:web` para solo la UI en navegador).

## 3. Pendientes / próximos pasos

### App Flutter (siguiente)
- [x] **Iteración 2**: pantallas de **Devices** (lista con online/offline, registro, renombrar, eliminar) y **Clipboard** (enviar texto + historial + updates en vivo, `device:identify`).
- [x] **Iteración 3**: **Files** con drag & drop (`desktop_drop`), upload con progreso (presigned PUT), shares y descargas.
- [x] Progreso de descarga visible por archivo (hoy solo snackbar) y cola de descargas.
- [x] Auto-copiar en el dispositivo destino al recibir `clipboard.updated` (hoy el copiado es manual con `super_clipboard`).
- [x] Sistema tray + autostart (`tray_manager`, `local_notifier`) para estar siempre disponible.
- [x] **Mobile** (iOS/Android) — primera pasada (Android APK + iOS simulador).
- [x] Decidir si se migra el resto de la UI a shadcn_flutter (tras validar el pilot).
- [x] **Recibir shares** (`receive_sharing_intent`) y **compartir** (`share_plus`) en Android.
- [ ] **Recibir shares en iOS** (Share Extension + SPM + App Groups en Xcode) y validar iOS en device real.

### Backend / operación
- [ ] Definir URLs reales de **QA y prod** (hoy placeholders en docs).
- [ ] Desplegar ambientes QA/prod (Postgres/Redis administrados, S3 AWS, secrets por ambiente).
- [ ] Empujar DTOs/eventos a `shared/protocol` cuando el frontend lo requiera.

### Pendiente de decisión
- [ ] **CocoaPods**: el `pod` de Homebrew queda shadowed por un gem de usuario con `ffi` rota. Para buildear se usa `PATH="/opt/homebrew/bin:$PATH" flutter ...`. Decidir si se deja fijo (remover el gem o ajustar el shell).

## 4. Registro de commits (rama `main`)

| Commit | Descripción |
|---|---|
| `314e28e` | App Flutter: dashboard y pantallas (devices/clipboard/files/compartidos) + tests |
| `03e24dc` | App Flutter: menús y dashboard, backend `senderDeviceId` en shares, AVANCE actualizado |
| `a5505f6` | Skills y workflow de Flutter (expert-flutter, testing, animations) |
| `2c422e1` | docs: documento de avance del proyecto (AVANCE.md) |
| `b2bb84b` | App Flutter base desktop (auth JWT, realtime, tema, shell) |
| `a425607` | Skills de agente |
| `dbbcf3a` | README general con diagramas end-to-end |
| `d8d9fc9` | Tests (Vitest+Supertest), exception filter, pino, health de dependencias, schemas Swagger |
| `7bb35eb` | Transacciones Prisma, strict TS, DTOs de query, FileMapper, constantes de eventos |
| `e0b25ca` | Seguridad: env fail-fast, rate limiting, CORS whitelist, helmet, shutdown hooks |
| `6e0bbc3` | Swagger UI + API.md con ambientes dev/QA/prod |
| `cd24012` | Transfers: shares con BullMQ, realtime y TTL |
| `9d2f733` | Realtime: gateway Socket.IO con auth JWT |
| `85e25ad` | Files: presigned URLs S3/MinIO |
| `179d688` | Clipboard: push/pull + historial + dedupe |
| `71a86e5` | Devices: CRUD + estado online |
| `860f7c7` | Auth + upgrade NestJS 11, Prisma 7, ESM |
| `4426447` | Scaffolding fase 1 (monorepo, backend, docker compose) |
