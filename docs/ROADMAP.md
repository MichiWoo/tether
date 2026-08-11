# Tether — Roadmap

Portapapeles y transferencia de archivos entre dispositivos (Windows, Linux, Mac, iOS, Android).

## Visión
Copiar texto o arrastrar archivos en un dispositivo y pegarlos en otro, vía cuenta + servidor central. Fase 2+: transferencia directa P2P por red local y Bluetooth sin internet.

## Stack técnico

| Capa | Tecnología | Por qué |
|---|---|---|
| UI | **Flutter** | Un codebase para 5 plataformas; drag & drop y clipboard nativo; widgets reactivos. |
| Backend | **NestJS** (Node + TypeScript) | WebSockets, DI, módulos, escala bien; mismo lenguaje que tooling. |
| Realtime | **Socket.IO** (socket.io en NestJS) | Notificaciones entre dispositivos, estado online/offline. |
| Queues/Jobs | **BullMQ + Redis** | Upload de archivos grandes, post-procesado, expiración de archivos, notificaciones. |
| Base de datos | **PostgreSQL** | Usuarios, dispositivos, historial de clipboard, shares. |
| Archivos | **S3 / MinIO** | Almacenamiento de objetos; **presigned URLs** (el archivo va directo cliente↔S3, el servidor no actúa de buffer). |
| Upload resumible | **TUS** (tus-js-client / tus-node) | Reanuda cortes de red, ideal para archivos grandes. |
| Auth | **JWT + OAuth2** | Login, refresh tokens, y **pairing por QR** para vincular dispositivos nuevos. |
| Infra | **Docker + Docker Compose** (dev), cloud en prod | Postgres, Redis, MinIO corren con un `docker compose up`. |

## Arquitectura general (MVP)

```
[Dispositivo A]  ──upload (chunked/TUS)──▶  ┌─────────────────────────────┐
   Flutter app                              │   Backend NestJS (Cloud)      │
                                            │  ┌─────────────────────────┐  │
                                            │  │ API REST (NestJS)       │  │
                                            │  │ WebSocket Gateway       │◀─┼── notificación real-time
                                            │  ├─────────────────────────┤  │
                                            │  │ BullMQ (jobs/queues)    │  │
                                            │  └─────────────────────────┘  │
                                            │   │         │         │       │
                                            │  Postgres  Redis   S3/MinIO  │
                                            └─────────────────────────────┘
                                                              │
[Dispositivo B]  ◀──notificación WebSocket──┘                  │
   Flutter app     ◀──descarga (presigned URL S3)──────────────┘
```

## Estructura del repositorio (monorepo)

```
Tether/
├── apps/
│   ├── mobile_app/          # Flutter (iOS + Android + macOS)
│   ├── desktop_app/         # Flutter (Windows + Linux + Mac)  ← o mismo proyecto Flutter con multi-target
│   └── backend/             # NestJS
├── shared/
│   ├── protocol/            # DTOs, eventos WebSocket, modelos compartidos
│   └── types/               # Tipos TS compartidos
└── docs/
```

> Decisión: **un solo proyecto Flutter** con targets desktop+mobile desde el inicio (compilar para 5 OS con banderas de plataforma en una misma base de código), en lugar de dos apps separadas.

## Módulos backend (NestJS)

1. **AuthModule** — registro/login, verificación email, JWT, QR pairing de dispositivos.
2. **DevicesModule** — CRUD de dispositivos propios, estado online/offline.
3. **ClipboardModule** — push/pull de texto, historial (últimos N items), auto-copiar en el destino.
4. **FilesModule** — presigned URLs (subida/descarga), multipart/TUS, metadatos (nombre, tamaño, tipo, checksum), carpetas virtuales.
5. **TransferModule** — jobs por transferencia: crear share → notificar → marcar como descargado/leído → TTL de expiración.
6. **RealtimeModule** (WebSocket) — eventos `share.created`, `share.accepted`, `clipboard.updated`, `device.online`.
7. **BillingModule** (fase posterior) — planes por volumen/bandwidth, medidor de uso por usuario (Stripe metered).

## Flujos principales del MVP

**A. Copiar texto A → pegar en B**
1. Usuario A copia texto (cliente detecta cambio de clipboard).
2. Cliente A envía `POST /clipboard` (o evento WS).
3. Backend guarda y emite `clipboard.updated` a B (si A eligió "enviar a B") o al resto de dispositivos.
4. B recibe, guarda en historial y **auto-copia al portapapeles** de B + notificación.

**B. Arrastrar archivo A → B**
1. En A, el usuario arrastra/suelta el archivo sobre el target B (o "enviar a…").
2. Cliente pide `POST /files` → recibe presigned URL y sube por chunks (TUS), con barra de progreso.
3. Al completar, job enqueue en BullMQ → evento `share.created` a B.
4. B notifica y pregunta "Guardar en Descargas / Carpeta" → descarga por presigned URL con progreso.
5. Job TTL limpia el archivo de S3 tras N días.

**C. Vincular un dispositivo nuevo**
1. En el dispositivo ya autenticado: "Agregar dispositivo" → QR.
2. Escanear QR desde la app nueva → intercambio de claves → dispositivo vinculado.

## Consideraciones Flutter por plataforma

- **Desktop (Win/Linux/Mac)**: `desktop_drop` (drag & drop), `super_clipboard`, `file_selector`, autostart + system tray para estar siempre disponible, background de detección de clipboard (`tray_manager`, `local_notifier`).
- **iOS/Android**: integración con Share Sheet nativa (`share_plus` + custom intent en Android para "enviar a Tether"), limitaciones de background (el envío/descarga debe ser iniciado por el usuario en foreground), `receive_sharing_intent` para recibir archivos.
- **Realtime**: `socket_io_client` con auto-reconnect y `background_fetch`/Workmanager para sincronización oportunista.
- **Estado**: Riverpod o Bloc (recomendable Riverpod para escalabilidad sin boilerplate).

## Fases de roadmap

| Fase | Alcance |
|---|---|
| **1. MVP (cloud)** | Auth + dispositivos + clipboard de texto + archivos vía cloud con progreso y notificaciones. |
| **2. P2P LAN (sin depender del cloud para la data)** | Descubrimiento local (mDNS/Bonjour) + transferencia directa por la misma red (WebRTC data channels o TCP directo). El servidor solo coordina. |
| **3. Sin internet (Bluetooth/WiFi directo)** | Pairing BLE + transferencia por Bluetooth RFCOMM o WiFi Direct/Hotspot. Rango corto, velocidad menor — útil como respaldo. |
| **4. Monetización** | Planes gratuitos/pagos por volumen de datos y ancho de banda (medidores + Stripe), expiración de archivos según plan. |

## Riesgos

- **Background en iOS/Android**: las descargas/upload largos se pausan en background → usar TUS (resumible) + iniciar siempre en foreground.
- **Velocidad**: en cloud el bottleneck es subida/descarga del usuario; presigned URLs + chunks evitan que el servidor reenvíe bytes.
- **Bluetooth es lento** para archivos grandes → solo como último recurso offline.
- **Seguridad**: cifrado en tránsito (TLS), archivos privados por usuario, checksums para integridad, expiración automática.
