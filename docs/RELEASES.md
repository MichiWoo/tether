# Tether — Releases y distribución de la app desktop

Cómo se versionan, compilan, firman y distribuyen los bins de la app desktop (Tauri)
para macOS / Windows / Linux, alojados en MinIO y expuestos vía API + landing.

## Resumen del flujo

```
git tag v0.2.0  ──▶  GitHub Actions (matrix: macos / windows / linux)
                        │  build Tauri + firmware minisign (.sig)
                        ▼
                 Sube artefactos a MinIO bucket "releases"  +  registra en backend
                        │
                        ▼
        GET /releases/latest        →  enlaces de descarga (landing)
        GET /releases/latest.json   →  manifest de auto-actualización (tauri-plugin-updater)
```

## 1. Versionado (fuente única)

La versión de la app vive en 3 archivos y se sincroniza con un script:

```bash
node scripts/bump-version.mjs 0.2.0          # actualiza + commit + tag v0.2.0
node scripts/bump-version.mjs 0.2.0 --no-commit  # solo actualiza archivos
```

Actualiza:

- `apps/tether_tauri/package.json`
- `apps/tether_tauri/src-tauri/tauri.conf.json`
- `apps/tether_tauri/src-tauri/Cargo.toml`

El tag `v*` dispara el workflow de CI (`.github/workflows/release.yml`).

## 2. Firmado (minisign) — clave del auto-update

El auto-updater de Tauri (`tauri-plugin-updater`) verifica que los artefactos estén
firmados con una clave minisign. Hay que generar **un único** keypair a nivel de
proyecto y conservarlo de forma segura.

```bash
# Genera la clave (guarda el secret en un password manager)
npx tauri signer generate -w ~/tauri-signing.key
# El output muestra la PUBLIC KEY que va en tauri.conf.json
npx tauri signer public-key -w ~/tauri-signing.key
```

Configuración:

- **`plugins.updater.pubkey`** en `tauri.conf.json` = la clave pública (embebida en la app).
- **`TAURI_SIGNING_PRIVATE_KEY`** = contenido de `~/tauri-signing.key` (secret de CI).
- **`TAURI_SIGNING_PRIVATE_KEY_PASSWORD`** = password del secret (si se generó con password).

> ⚠️ Si se pierde o regenera el keypair, las apps ya publicadas **no podrán actualizarse**
> con las nuevas releases (firma distinta). Consérvala como un secreto de infraestructura.

## 3. Bucket de releases en MinIO

Los bins se alojan en un bucket separado del bucket de archivos de usuario
(`MINIO_RELEASES_BUCKET`, default `releases`). El backend lo crea automáticamente al
arrancar (igual que el bucket de archivos).

Convención de keys:

```
releases/{version}/{os}/{arch}/{filename}
# ejemplos
releases/0.2.0/macos/aarch64/Tether_0.2.0_aarch64.app.tar.gz
releases/0.2.0/macos/aarch64/Tether_0.2.0_aarch64.app.tar.gz.sig
releases/0.2.0/windows/x86_64/Tether_0.2.0_x64-setup.exe
releases/0.2.0/linux/x86_64/tether-app_0.2.0_amd64.AppImage
```

### TLS / acceso desde CI

El backend se conecta a MinIO internamente (`MINIO_ENDPOINT` + puerto `9000`, sin TLS en
la red interna). Para que el CI suba los artefactos, MinIO está expuesto al exterior con
TLS terminado en el edge (`https://api.storage.woowebs.cloud`), que equivale a
`minio:9000` interno. El cliente del CI usa mode path-style S3v4 contra ese endpoint.

Credenciales (fuertes, distintas de dev) van a los secrets de CI:

| Secret de CI | Descripción |
|---|---|
| `S3_ENDPOINT` | `https://api.storage.woowebs.cloud` |
| `S3_ACCESS_KEY` | Access key de MinIO (la misma `MINIO_ACCESS_KEY`) |
| `S3_SECRET_KEY` | Secret key de MinIO (la misma `MINIO_SECRET_KEY`) |
| `RELEASES_API_KEY` | Key para `POST /releases` (coincide con `RELEASES_API_KEY` del backend) |
| `TAURI_SIGNING_PRIVATE_KEY` | Clave privada minisign del proyecto |
| `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` | (opcional) password de la clave |

## 4. Backend — módulo `releases`

Modelo Prisma `Release` (ver `apps/backend/src/releases/`), con migración
`prisma/migrations/*_add_releases`.

| Método | Ruta | Descripción |
|---|---|---|
| GET | `/releases/latest?channel=&platform=&arch=` | Última versión publicada + URL presignada de descarga |
| GET | `/releases` | Lista plana de releases publicados |
| GET | `/releases/latest.json` | Manifest de auto-actualización (tauri-plugin-updater) |
| GET | `/releases/:id/download` | 302 → URL presignada fresca |
| POST | `/releases` | Registra un artefacto. Protegido con `x-api-key` (`RELEASES_API_KEY`) |

> Las URLs presignadas de descarga tienen TTL de 7 días. El manifest `latest.json` se
> regenera en cada request, por lo que el auto-update siempre recibe URLs vigentes.

### Variables de entorno (nuevas)

| Variable | Default | Descripción |
|---|---|---|
| `MINIO_RELEASES_BUCKET` | `releases` | Bucket de artefactos de releases |
| `MINIO_PUBLIC_ENDPOINT` | *(vacío)* | Endpoint público (TLS) usado para firmar las URLs presignadas de descarga. Obligatorio en prod para que el updater/landing descarguen por HTTPS |
| `RELEASES_API_KEY` | *(vacío = POST rechazado)* | API key para registrar releases desde CI |

## 5. Auto-actualización en la app

- Plugins: `tauri-plugin-updater` y `tauri-plugin-process` (Rust) + `@tauri-apps/plugin-updater`,
  `@tauri-apps/plugin-process` (JS).
- `bundle.createUpdaterArtifacts: true` genera los `.sig`/firmas en el build.
- UI en `Apps → Perfil → Actualizaciones` (`apps/tether_tauri/src/features/profile/ProfileScreen.vue`).
- Lógica en `apps/tether_tauri/src/core/updater.ts`.
- Endpoint configurado en `tauri.conf.json`: `https://tether.app/releases/latest.json`
  (ajústalo a tu dominio real).

## 6. CI (GitHub Actions)

Workflow en `.github/workflows/release.yml`:

- Disparo: `push` de tags `v*`.
- Matrix de 3 runners:
  - `macos-latest` → `.dmg` + `.app.tar.gz` (aarch64 + x86_64)
  - `windows-latest` → `.msi` + `.exe` (NSIS)
  - `ubuntu-22.04` → `.deb` + `.rpm` + `.AppImage`
- Steps: build Tauri (firmada) → recopilar + `SHA256SUMS` → subir a MinIO (`mc`) →
  `POST /releases` por artefacto.

### Primer despliegue (checklist)

1. Generar keypair minisign y poner `pubkey` en `tauri.conf.json` + secret privado en CI.
2. Definir los secrets/vars de CI (tabla del punto 3).
3. Exponer MinIO con TLS y configurar `MINIO_RELEASES_BUCKET` + `RELEASES_API_KEY` en `.env`.
4. `node scripts/bump-version.mjs 0.2.0` + `git push --follow-tags`.
5. Verificar `GET /releases/latest` y que la landing muestre los enlaces.
6. En el `.env` de prod del servicio `web`, fijar
   `PUBLIC_API_BASE_URL=https://api.tether.woowebs.cloud` si el proxy
   mismo-origen (`/releases → backend:3100`) no alcanza al backend
   (la landing pide las descargas en runtime y necesita una ruta que responda).

> La landing resuelve los botones en el navegador con `fetch(<PUBLIC_API_BASE_URL>/releases/latest?channel=stable)`.
> Si ves todo en "Próximamente": abrí DevTools → Network y mirá qué responde
> esa request (502 = proxy roto; fallo CORS = falta el origen en `CORS_ORIGINS`
> del backend; `[]` = DB sin releases registrados por el CI).

## 7. Comandos para subir un release (tag)

El workflow de CI se dispara con el push de un tag `v*`. Dos casos posibles:

### 7.1 Publicar un release nuevo (bump de versión)

Crea commit + tag y lo publica:

```bash
# Bumpea versión (actualiza package.json, tauri.conf.json y Cargo.toml) + commit + tag
pnpm release 0.2.0

# Sube commits y tags
git push --follow-tags
```

> Nota: `git push --follow-tags` a veces no sube el tag si apunta al commit recién
> pusheado en el mismo push. Si el tag no aparece en GitHub, subilo explícitamente
> (ver 7.2).

### 7.2 Re-disparar un tag existente (sin bumpear)

GitHub **no re-ejecuta** un workflow para un tag que ya existe. Si necesitás reintentar
(tras un fix al workflow, por ejemplo), hay que borrar y recrear el tag:

```bash
# Borra el tag remoto y local, y lo recrea sobre el commit actual de main
git push origin :v0.2.0
git tag -d v0.2.0
git tag v0.2.0
git push origin v0.2.0
```

Esto es lo que se usa cada vez que cambió el código (fix de CI, nueva pubkey, etc.)
y querés que el pipeline vuelva a correr sobre los cambios.

### 7.3 Subir un tag puntual (sin bump, sin borrar)

```bash
git tag v0.2.0
git push origin v0.2.0
```

### Verificar que el tag llegó

```bash
git ls-remote --tags origin
```

### Monitorear

- GitHub → repo → **Actions** → workflow **"Release"**: 3 jobs en paralelo
  (macOS / Windows / Linux).
- Si falla la firma, revisar que `TAURI_SIGNING_PRIVATE_KEY` y
  `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` (secrets) coincidan con el keypair cuya
  `pubkey` está embebida en `tauri.conf.json`.

## Referencias

- Tauri updater: https://tauri.app/plugin/updater/
- Tauri distribuir/actualizar: https://tauri.app/distribute/
