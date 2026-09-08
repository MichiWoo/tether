# Tether — Build Android (APK desde Tauri)

Cómo generar el APK Android de `apps/tether_tauri` (Tauri v2): entorno, firma
release con keystore, build, verificación e instalación.

> La app desktop (macOS/Windows/Linux) se documenta en `RELEASES.md`.
> El APK Android **no** usa el auto-updater (las stores gestionan updates);
> en móvil `tauri-plugin-updater` y `tauri-plugin-autostart` están desactivados
> por diseño (`src-tauri/src/lib.rs`, ramas `#[cfg(desktop)]`).

## 0. Decisiones fijadas del proyecto

| Decisión | Valor |
|---|---|
| `applicationId` / identifier | `app.tether.app` (`src-tauri/tauri.conf.json`) |
| Backend compilado en el APK | `https://api.tether.woowebs.cloud` (vía `VITE_API_BASE_URL`) |
| Formato | APK universal release firmado (4 ABIs: arm64-v8a, armeabi-v7a, x86, x86_64) |
| Script repetible | `apps/tether_tauri/scripts/build-android-apk.sh` |

## 1. Requisitos (una sola vez por máquina)

```bash
# 1. Android SDK + NDK 28 (16KB pages) + build-tools
#    SDK en ~/Library/Android/sdk, NDK 28.2.13676358 instalado

# 2. Rust targets Android
rustup target add aarch64-linux-android armv7-linux-androideabi \
  i686-linux-android x86_64-linux-android

# 3. Java 17 — OJO: el JDK de Homebrew NO lo ve `java_home` de macOS,
#    hay que exportar la ruta completa:
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"

# 4. Variables de entorno (persistidas en ~/.zshrc)
export ANDROID_HOME="$HOME/Library/Android/sdk"
export NDK_HOME="$ANDROID_HOME/ndk/28.2.13676358"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
```

## 2. Proyecto Android (ya inicializado, solo si hay que regenerar)

```bash
cd apps/tether_tauri
pnpm tauri android init   # genera src-tauri/gen/android/ (gitignored)
```

> ⚠️ Regenerar con `init` **sobrescribe** `gen/android/app/build.gradle.kts`:
> re-aplicar el bloque `signingConfigs.release` (ver punto 4) si se pierde.

## 3. Keystore de firma (una sola vez, NO commitear)

```bash
# Genera passwords aleatorios (guárdalos en un password manager)
STOREPASS=$(openssl rand -base64 24 | tr -d '/+=' | cut -c1-24)
mkdir -p ~/.config/tether
printf 'STOREPASS=%s\nKEYPASS=%s\n' "$STOREPASS" "$STOREPASS" > ~/.config/tether/keystore-passwords.txt
chmod 600 ~/.config/tether/keystore-passwords.txt

# Genera el keystore (validez ~27 años; PKCS12 unifica store/key password)
keytool -genkey -v -keystore ~/.config/tether/tether-release.jks \
  -alias tether -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$STOREPASS" \
  -dname "CN=Tether, OU=Tether, O=Tether, L=Tether, ST=Tether, C=MX"
```

Firma automática en Gradle vía `src-tauri/gen/android/keystore.properties` (gitignored):

```bash
source ~/.config/tether/keystore-passwords.txt
printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=tether\nstoreFile=%s/.config/tether/tether-release.jks\n' \
  "$STOREPASS" "$STOREPASS" "$HOME" > apps/tether_tauri/src-tauri/gen/android/keystore.properties
chmod 600 apps/tether_tauri/src-tauri/gen/android/keystore.properties
```

> ⚠️ Si se pierde el keystore, las instalaciones existentes **no podrán
> actualizarse** con APKs firmados con otra clave (firma distinta = app distinta
> para Android). Backup fuera de la máquina.

## 4. Build del APK (comando completo)

```bash
cd apps/tether_tauri
export ANDROID_HOME=$HOME/Library/Android/sdk \
       NDK_HOME=$HOME/Library/Android/sdk/ndk/28.2.13676358 \
       JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" \
       VITE_API_BASE_URL=https://api.tether.woowebs.cloud

# Atajo (build + firma + verificación):
./scripts/build-android-apk.sh

# O paso a paso:
pnpm tauri android build --apk --ci
```

El `beforeBuildCommand` de Tauri (`pnpm typecheck && vite build`) hereda
`VITE_API_BASE_URL` del entorno: esa URL queda embebida en el bundle web del APK.
`localhost` **no sirve** en un móvil físico (apunta al propio teléfono).

Artefactos en `src-tauri/gen/android/app/build/outputs/apk/universal/release/`:

| Archivo | Descripción |
|---|---|
| `app-universal-release-unsigned.apk` | Salida directa de Gradle (si no aplicó firma) |
| `app-universal-release.apk` | ✅ **Final firmado, listo para instalar/distribuir** |

Si Gradle deja el APK como `*-unsigned.apk` (el template de Tauri no siempre
aplica el `signingConfigs`), firma manual:

```bash
BT=$ANDROID_HOME/build-tools/36.0.0
OUT=src-tauri/gen/android/app/build/outputs/apk/universal/release
source ~/.config/tether/keystore-passwords.txt
export TETHER_STOREPASS="$STOREPASS"
$BT/zipalign -f 4 $OUT/app-universal-release-unsigned.apk $OUT/app-aligned.apk
$BT/apksigner sign --ks ~/.config/tether/tether-release.jks \
  --ks-pass env:TETHER_STOREPASS --ks-key-alias tether \
  --out $OUT/app-universal-release.apk $OUT/app-aligned.apk
unset TETHER_STOREPASS
```

## 5. Verificación

```bash
BT=$ANDROID_HOME/build-tools/36.0.0
OUT=src-tauri/gen/android/app/build/outputs/apk/universal/release
$BT/apksigner verify --print-certs $OUT/app-universal-release.apk
$BT/aapt dump badging $OUT/app-universal-release.apk | head -3
# Esperado: package='app.tether.app' versionCode='…' + certificado CN=Tether
```

## 6. Instalación en dispositivo

```bash
adb devices                      # el móvil debe aparecer (depuración USB)
adb install -r $OUT/app-universal-release.apk
```

## 7. Notas de la adaptación móvil (ya aplicadas en el código)

- `src-tauri/src/lib.rs` tiene ramas `#[cfg(mobile)]`: keyring → archivo
  privado de la app (`app_data_dir`, sin cifrado hardware todavía), dialogs
  `blocking_*` → callbacks async, autostart/updater desactivados.
- `src-tauri/capabilities/default.json` incluye `dialog:default`.
- En Android, tokens y estado van al directorio privado de la app; el auto-update
  del frontend (`src/core/updater.ts`) devuelve estado `error` controlado.
- Pendiente a futuro: Android Keystore real, share-sheet nativo, ergonomía
  táctil del layout (hoy es ventana desktop 1180×760).

## 8. CI (GitHub Actions)

El APK se genera junto a desktop en el mismo workflow (`.github/workflows/release.yml`,
job `build-android`, trigger tags `v*`). No requiere cambios de código móvil:
el job regenera `gen/` con `tauri android init`, compila, firma y registra.

Flujo del job:

```
tag v* ──▶ build-android (ubuntu-22.04: Java 17 + SDK/NDK 28 + Rust targets)
             │  tauri android build --apk (VITE_API_BASE_URL = secrets.API_BASE_URL)
             │  zipalign + apksigner con el keystore de secrets
             ▼
         mc cp → MinIO releases/{version}/android/universal/Tether_{version}_universal.apk
         POST /releases (platform=android, arch=universal, isPrimary=true, signature=null)
             ▼
         La landing lo muestra como botón principal de Android (descarga vía URL presignada)
```

Secrets (Settings → Secrets and variables → Actions):

| Secret | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | `base64 -i ~/.config/tether/tether-release.jks \| tr -d '\n'` (mismo keystore local: conserva la identidad de firma) |
| `ANDROID_KEYSTORE_PASSWORD` | `STOREPASS` de `~/.config/tether/keystore-passwords.txt` (sin salto de línea) |
| `ANDROID_KEY_ALIAS` | `tether` |

Notas:

- El backend acepta `platform: android` (`RELEASE_PLATFORMS` en
  `register-release.dto.ts`); con `signature: null` queda fuera del manifest
  del auto-updater desktop automáticamente.
- El artefacto final se renombra a `Tether_{version}_universal.apk` (convención
  del proyecto) y se publica también como workflow artifact `tether-android`.

## 9. Troubleshooting

| Síntoma | Causa / solución |
|---|---|
| `Unable to locate a Java Runtime` en Gradle | `JAVA_HOME` vacío: exportar la ruta Homebrew del punto 1 (`java_home -v 17` no la detecta) |
| `failed to find tool "/toolchains/llvm/…"` | `NDK_HOME` vacío en ese shell: exportarlo (punto 1) |
| APK `*-unsigned.apk` | El template no aplicó firma → firma manual (punto 4) o revisar `signingConfigs` en `gen/android/app/build.gradle.kts` + `keystore.properties` |
| Error `keyring`/`autostart` compilando para Android | Regresión desktop-only en `lib.rs`: gatear con `#[cfg(desktop)]` + stub `#[cfg(mobile)]` |
| App abre pero no conecta | Revisar `VITE_API_BASE_URL` del build (en emulador usar `http://10.0.2.2:3100`; en físico, IP LAN o HTTPS prod). Release bloquea cleartext HTTP por defecto |
| `adb devices` vacío | Activar depuración USB + aceptar el diálogo RSA en el móvil |
| Falla `sdkmanager --licenses` en CI | Correrlo con `yes \|` delante y con `ANDROID_HOME` del runner (el job `build-android` ya lo hace) |
| `apksigner` falla en CI con keystore corrupto | El secret `ANDROID_KEYSTORE_BASE64` debe ser de **una sola línea** (`tr -d '\n'` al generarlo); multilínea rompe el `base64 -d` |
| `apksigner: keystore password was incorrect` | El password lleva un `\n` final: regenerar el secret con `printf '%s'` (sin salto de línea) |
| `No key with alias 'tether'` | Revisar `ANDROID_KEY_ALIAS`; el alias del keystore se lista con `keytool -list -keystore ~/.config/tether/tether-release.jks` |

## Referencias

- Tauri v2 mobile: https://tauri.app/develop/mobile/
- Script: `apps/tether_tauri/scripts/build-android-apk.sh`
