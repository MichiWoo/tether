# Tether — Documentación de la API

API REST + WebSocket del backend (NestJS) de Tether: portapapeles y transferencia de archivos entre dispositivos.

## 1. Swagger / OpenAPI

La API está documentada con **OpenAPI 3** generada automáticamente desde el código (`@nestjs/swagger`).

| Recurso | URL |
|---|---|
| Swagger UI | `{BASE_URL}/docs` |
| Spec OpenAPI (JSON) | `{BASE_URL}/docs-json` |

- **Autenticación en Swagger UI:** usa el botón **Authorize** (candado) y pega el `accessToken` como `Bearer <token>`.
- La opción `persistAuthorization` está activa, así el token se conserva entre recargas.
- Desde Swagger puedes probar todos los endpoints autenticados directamente.

## 2. Ambientes

La API se despliega en 3 ambientes. La URL base y las credenciales de acceso se configuran por **variables de entorno** (`.env`), nunca en el código.

| Ambiente | Base URL (ejemplo) | Uso |
|---|---|---|
| **Desarrollo (dev)** | `http://localhost:3100` | Maquina local de cada dev |
| **QA / staging** | `https://api-qa.tether.app` *(placeholder)* | Validación de integración y pre-producción |
| **Producción (prod)** | `https://api.tether.app` *(placeholder)* | Tráfico real de usuarios |

> Reemplaza los URLs de QA/prod por los dominios reales cuando existan.

### 2.1 Acceso a Desarrollo (dev)

Todo corre con Docker + pnpm en el monorepo.

```bash
# 1. Levantar infraestructura (Postgres, Redis, MinIO)
pnpm db:up          # docker compose up -d

# 2. Migraciones (solo la primera vez o al cambiar el schema)
pnpm --filter @tether/backend exec prisma migrate dev

# 3. Levantar el backend
pnpm dev:backend    # nest start --watch → http://localhost:3100
```

Accesos del entorno dev:

| Servicio | URL | Credenciales |
|---|---|---|
| API + Swagger | http://localhost:3100 / `/docs` | — |
| PostgreSQL | `localhost:5434` (bd/user/pass: `tether`) | — |
| Redis | `localhost:6379` | — |
| MinIO (S3) | http://localhost:9000 | `minioadmin` / `minioadmin` |
| Consola MinIO | http://localhost:9001 | `minioadmin` / `minioadmin` |

> Nota: el Postgres de dev mapea el puerto **5434** (no 5432) para no chocar con otros Postgres locales, y la API usa **3100** (el 3000 lo usa otro proyecto). Ambos son configurables por env.

### 2.2 Acceso a QA y Producción

Para cada ambiente se proveen **variables de entorno distintas**. Lo mínimo que hay que configurar en QA y prod:

| Variable | QA (ejemplo) | Prod (ejemplo) |
|---|---|---|
| `NODE_ENV` | `qa` | `production` |
| `PORT` | `3100` | `3100` |
| `DATABASE_URL` | Postgres administrado del ambiente | Postgres administrado de prod |
| `REDIS_HOST` / `REDIS_PORT` | Redis del ambiente | Redis de prod |
| `MINIO_ENDPOINT` / `MINIO_PORT` | MinIO/S3 del ambiente | S3 de prod (AWS) |
| `MINIO_USE_SSL` | `true` | `true` |
| `MINIO_ACCESS_KEY` / `MINIO_SECRET_KEY` | credenciales del ambiente | credenciales AWS |
| `MINIO_BUCKET` | `tether-qa` | `tether-prod` |
| `JWT_SECRET` | secreto aleatorio de QA | secreto aleatorio de prod |
| `REFRESH_TOKEN_SECRET` | secreto aleatorio de QA | secreto aleatorio de prod |
| `SHARE_TTL_DAYS` | `7` | `7` (o según plan) |
| `CORS_ORIGINS` | `https://app-qa.tether.app` | `https://app.tether.app` |

Pasos para subir un ambiente:

```bash
# 1. Generar el build de producción (ESM)
pnpm --filter @tether/backend build

# 2. Aplicar migraciones contra la BD del ambiente
pnpm --filter @tether/backend exec prisma migrate deploy

# 3. Arrancar el servidor
node apps/backend/dist/main.js
```

**Verificación de un ambiente:**

```bash
curl https://api.tether.app/health        # → {"status":"ok",...}
curl https://api.tether.app/docs          # → Swagger UI
```

**Reglas de seguridad por ambiente:**
- `JWT_SECRET` y `REFRESH_TOKEN_SECRET` deben ser distintos entre QA y prod, generados con `openssl rand -hex 48`, y rotarse ante fuga.
- Los buckets de MinIO/S3 deben ser distintos por ambiente (`tether-dev`, `tether-qa`, `tether-prod`).
- En QA/prod usa Postgres y Redis administrados (no los contenedores del `docker-compose.yml`, que son solo para dev).
- `CORS_ORIGINS` es una lista separada por comas de orígenes permitidos (`*` = todos, solo para dev). El arranque **falla rápido** si faltan o son inválidas las variables de entorno obligatorias (Joi).

**Protecciones activas:** rate limiting global (`@nestjs/throttler`, 100 req/min) con límites más estrictos en `auth` (register 5/min, login 10/min, refresh 30/min, responden `429` con `Retry-After`), headers de seguridad `helmet`, CORS por lista blanca y `enableShutdownHooks`.

**Errores:** formato unificado via `GlobalExceptionFilter` → `{ statusCode, message, error, path, timestamp }`. Logging estructurado con pino (pretty en dev, JSON en QA/prod, configurable con `LOG_LEVEL`).

## 3. Autenticación

Flujo JWT con **access token corto** y **refresh token rotativo**.

1. `POST /auth/register` o `POST /auth/login` → devuelve `{ accessToken, refreshToken, user }`.
2. Envía `Authorization: Bearer <accessToken>` en cada request protegido.
3. Cuando el access token expire (401), llama `POST /auth/refresh` con el refresh token → obtienes un **par nuevo** (el anterior queda revocado).
4. `POST /auth/logout` revoca el refresh token.

| Token | Caducidad | Uso |
|---|---|---|
| `accessToken` | `JWT_EXPIRES_IN` (default 15m) | Bearer en los requests |
| `refreshToken` | `REFRESH_TOKEN_EXPIRES_IN` (default 30d) | Rotar/cerrar sesión |

**Códigos de error comunes:** `401` no autenticado / credenciales inválidas · `403` prohibido · `404` recurso no encontrado o ajeno · `409` email ya registrado · `400` validación.

## 4. Endpoints

Todos los endpoints bajo `auth` son públicos salvo `GET /auth/me`. El resto requiere `Bearer <accessToken>`.

### auth
| Método | Ruta | Descripción |
|---|---|---|
| POST | `/auth/register` | Registrar usuario → tokens |
| POST | `/auth/login` | Iniciar sesión → tokens |
| POST | `/auth/refresh` | Rotar refresh token |
| POST | `/auth/logout` | Revocar refresh token |
| GET | `/auth/me` | Perfil del usuario autenticado |

### devices
| Método | Ruta | Descripción |
|---|---|---|
| POST | `/devices` | Registrar dispositivo (`name`, `platform`, `pushToken?`) |
| GET | `/devices` | Listar dispositivos propios con `isOnline` |
| GET | `/devices/:id` | Ver dispositivo propio |
| PATCH | `/devices/:id` | Renombrar / actualizar pushToken |
| DELETE | `/devices/:id` | Desvincular dispositivo |
| POST | `/devices/:id/heartbeat` | Marcar online (ventana de 2 min) |

`platform` acepta: `ios`, `android`, `windows`, `linux`, `macos`, `web` (se normaliza a mayúsculas).

### clipboard
| Método | Ruta | Descripción |
|---|---|---|
| POST | `/clipboard` | Subir texto (`content`, `sourceDeviceId?`). Dedupe por contenido+device. Emite `clipboard.updated` |
| GET | `/clipboard/latest` | Último texto |
| GET | `/clipboard/history?limit=N` | Historial (default 20, máx 100) |

Body JSON limitado a 5MB (texto grande de clipboard).

### files
| Método | Ruta | Descripción |
|---|---|---|
| POST | `/files` | Registrar archivo → devuelve presigned URL PUT (TTL 15m) |
| GET | `/files` | Listar archivos (`limit`, default 50) |
| GET | `/files/:id` | Presigned URL GET de descarga (TTL 1h) |
| POST | `/files/:id/complete` | Confirmar subida (verifica en S3) → `UPLOADED`, emite `file.ready` |
| DELETE | `/files/:id` | Borrar registro + objeto S3 |

**Flujo de subida (directo cliente↔S3, el servidor no actúa de buffer):**

```bash
# 1. Registrar
curl -X POST $BASE/files -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
  -d '{"name":"foto.jpg","size":12,"mimeType":"image/jpeg"}'
# → { file: {...}, upload: { url: "<PUT presigned>", method: "PUT", headers: { "Content-Type": "image/jpeg" } } }

# 2. Subir directo a MinIO/S3
curl -X PUT "$URL_PRESIGNED" -H "Content-Type: image/jpeg" --data-binary @foto.jpg

# 3. Confirmar
curl -X POST $BASE/files/$FILE_ID/complete -H "Authorization: Bearer $TOK"
```

### transfers (`/shares`)
| Método | Ruta | Descripción |
|---|---|---|
| POST | `/shares` | Crear share (`fileId`, `targetDeviceId?`). Encola job → emite `share.created` |
| GET | `/shares?status=` | Listar shares (`CREATED`/`ACCEPTED`/`DOWNLOADED`/`EXPIRED`) |
| GET | `/shares/:id` | Detalle + presigned URL de descarga |
| POST | `/shares/:id/accept` | Aceptar → `ACCEPTED`, emite `share.accepted` |
| POST | `/shares/:id/downloaded` | Marcar descargado → `DOWNLOADED`, emite `share.downloaded` |
| POST | `/shares/:id/cancel` | Cancelar → `EXPIRED` |

TTL de expiración por `SHARE_TTL_DAYS` (default 7). Un job de BullMQ expira los shares vencidos y borra el archivo de S3.

### sistema
| Método | Ruta | Descripción |
|---|---|---|
| GET | `/health` | Health check (público): `status`, `version`, `uptime` + **`checks`** de dependencias (`database`, `redis`, `storage`) |
| GET | `/` | Nombre y estado del servicio (público) |

## 5. WebSocket (realtime)

Socket.IO en la ruta **`/realtime`** (path custom, no el `/socket.io` por defecto).

**Conexión** (se autentica en el handshake con el access token):

```js
const socket = io(BASE_URL, {
  path: '/realtime',
  auth: { token: accessToken },
});
```

- Conexión con token inválido → el servidor la cierra.
- Al conectar, el cliente entra a la sala de su usuario. Luego se identifica con un device:

```js
socket.emit('device:identify', { deviceId });
```

**Eventos que emite el servidor:**

| Evento | Cuándo | Payload |
|---|---|---|
| `device.online` | Un device se identifica | `{ deviceId }` |
| `device.offline` | Un device se desconecta | `{ deviceId }` |
| `clipboard.updated` | Se sube texto | `{ item, sourceDeviceId }` |
| `file.ready` | Un archivo se marca UPLOADED | `{ file }` |
| `share.created` | Se crea un share | `{ share }` |
| `share.accepted` | Share aceptado | `{ share }` |
| `share.downloaded` | Share descargado | `{ share }` |
| `share.expired` | Share expirado | `{ shareId }` |

Los eventos dirigidos a un device (`share.created` con `targetDeviceId`) solo llegan al socket que se identificó con ese device. El resto va a todos los sockets del usuario.
