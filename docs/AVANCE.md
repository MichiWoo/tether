# Tether — Avance del proyecto

Este documento registra el estado actual del proyecto y lo que queda pendiente. Se actualiza al cierre de cada sesión.

> **Última actualización:** 11/08/2026 (cierre de sesión)

## Estado general

| Fase | Backend | App Flutter | Estado |
|---|---|---|---|
| **1. MVP (cloud)** | Completado | En curso (iteración 1 lista) | En desarrollo |
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

## 3. Pendientes / próximos pasos

### App Flutter (siguiente)
- [ ] **Iteración 2**: pantallas de **Devices** (lista con online/offline, registro, renombrar, eliminar) y **Clipboard** (enviar texto + historial + updates en vivo, `device:identify`).
- [ ] **Iteración 3**: **Files** con drag & drop (`desktop_drop`), upload con progreso (presigned PUT), shares y descargas.
- [ ] Añadir `super_clipboard` (auto-copiar en destino) y `file_selector`.
- [ ] Sistema tray + autostart (`tray_manager`, `local_notifier`) para estar siempre disponible.
- [ ] **Mobile** (iOS/Android) después de estabilizar desktop.

### Backend / operación
- [ ] Definir URLs reales de **QA y prod** (hoy placeholders en docs).
- [ ] Desplegar ambientes QA/prod (Postgres/Redis administrados, S3 AWS, secrets por ambiente).
- [ ] Integrar **TransferModule** con la app (consumir eventos `share.created` → notificación + descarga).
- [ ] Empujar DTOs/eventos a `shared/protocol` cuando el frontend lo requiera.

### Pendiente de decisión
- [ ] **CocoaPods**: el `pod` de Homebrew queda shadowed por un gem de usuario con `ffi` rota. Para buildear se usa `PATH="/opt/homebrew/bin:$PATH" flutter ...`. Decidir si se deja fijo (remover el gem o ajustar el shell).

## 4. Registro de commits (rama `main`)

| Commit | Descripción |
|---|---|
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
