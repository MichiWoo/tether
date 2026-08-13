# Tether — Avance del proyecto

Este documento registra el estado actual del proyecto y lo que queda pendiente. Se actualiza al cierre de cada sesión.

> **Última actualización:** 12/08/2026 (cierre de sesión — iteración 3 Files/Transfers lista)

## Estado general

| Fase | Backend | App Flutter | Estado |
|---|---|---|---|
| **1. MVP (cloud)** | Completado | Iteración 3 lista (Files + Compartidos) | En desarrollo |
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
| **Files** | presigned URLs S3/MinIO (upload/descarga directa cliente↔S3), `complete` verifica en S3, TTL | ✅ |
| **Realtime** | Gateway Socket.IO en `/realtime`, auth JWT en handshake, rooms por usuario/device, eventos en vivo | ✅ |
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

`docker-compose.yml`: Postgres 16 (`:5434`), Redis 7 (`:6379`), MinIO (`:9000`/`:9001`). La API corre en `:3100`.

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

## 3. Pendientes / próximos pasos

### App Flutter (siguiente)
- [x] **Iteración 2**: pantallas de **Devices** (lista con online/offline, registro, renombrar, eliminar) y **Clipboard** (enviar texto + historial + updates en vivo, `device:identify`).
- [x] **Iteración 3**: **Files** con drag & drop (`desktop_drop`), upload con progreso (presigned PUT), shares y descargas.
- [ ] Progreso de descarga visible por archivo (hoy solo snackbar) y cola de descargas.
- [ ] Auto-copiar en el dispositivo destino al recibir `clipboard.updated` (hoy el copiado es manual con `super_clipboard`).
- [ ] Sistema tray + autostart (`tray_manager`, `local_notifier`) para estar siempre disponible.
- [ ] **Mobile** (iOS/Android) después de estabilizar desktop.

### Backend / operación
- [ ] Definir URLs reales de **QA y prod** (hoy placeholders en docs).
- [ ] Desplegar ambientes QA/prod (Postgres/Redis administrados, S3 AWS, secrets por ambiente).
- [ ] Empujar DTOs/eventos a `shared/protocol` cuando el frontend lo requiera.

### Pendiente de decisión
- [ ] **CocoaPods**: el `pod` de Homebrew queda shadowed por un gem de usuario con `ffi` rota. Para buildear se usa `PATH="/opt/homebrew/bin:$PATH" flutter ...`. Decidir si se deja fijo (remover el gem o ajustar el shell).

## 4. Registro de commits (rama `main`)

| Commit | Descripción |
|---|---|
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
