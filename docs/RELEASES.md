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

MinIO en el `docker-compose.yml` base queda en red interna (sin puerto público). Para
que el CI pueda subir artefactos, expón MinIO a través del edge con TLS terminando en
`minio:9000` (por ejemplo Caddy/Traefik/Dokploy en `https://s3.tether.app`).

Credenciales (fuertes, distintas de dev) van a los secrets de CI:

| Secret de CI | Descripción |
|---|---|
| `S3_ENDPOINT` | `https://s3.tether.app` |
| `S3_ACCESS_KEY` | Access key de MinIO (con permiso al bucket `releases`) |
| `S3_SECRET_KEY` | Secret key de MinIO |
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

## Referencias

- Tauri updater: https://tauri.app/plugin/updater/
- Tauri distribuir/actualizar: https://tauri.app/distribute/
