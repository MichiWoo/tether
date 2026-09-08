#!/usr/bin/env bash
# Genera el APK Android release de Tether (Tauri) firmado con el keystore
# de producción.
#
# Uso:
#   ./scripts/build-android-apk.sh
#
# Requisitos (una sola vez):
#   - Android SDK + NDK 28 en $ANDROID_HOME (ver README / docs de Tauri v2)
#   - Rust targets: aarch64/armv7/i686/x86_64-linux-android
#   - Java 17: export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
#   - Keystore: ~/.config/tether/tether-release.jks
#     + passwords en ~/.config/tether/keystore-passwords.txt (chmod 600):
#         STOREPASS=<pass>
#         KEYPASS=<pass>   (PKCS12 usa el storepass para la clave)
#   - Firma automática: src-tauri/gen/android/keystore.properties (gitignored):
#         storePassword=<pass>
#         keyPassword=<pass>
#         keyAlias=tether
#         storeFile=$HOME/.config/tether/tether-release.jks
#
# Si el build sale "unsigned" (el template de Tauri no aplicó el signing),
# este script lo alinea y firma a mano con zipalign/apksigner.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
API_URL="${VITE_API_BASE_URL:-https://api.tether.woowebs.cloud}"
KEYSTORE="${TETHER_KEYSTORE:-$HOME/.config/tether/tether-release.jks}"
PASS_FILE="${TETHER_PASS_FILE:-$HOME/.config/tether/keystore-passwords.txt}"
BT="${ANDROID_HOME:?ANDROID_HOME no definido}/build-tools/36.0.0"
OUT="$APP_DIR/src-tauri/gen/android/app/build/outputs/apk/universal/release"

export JAVA_HOME="${JAVA_HOME:?JAVA_HOME no definido (Java 17)}"
export NDK_HOME="${NDK_HOME:?NDK_HOME no definido}"
export VITE_API_BASE_URL="$API_URL"

cd "$APP_DIR"
pnpm tauri android build --apk --ci

UNSIGNED="$OUT/app-universal-release-unsigned.apk"
FINAL="$OUT/app-universal-release.apk"

if [ -f "$FINAL" ] && "$BT/apksigner" verify "$FINAL" >/dev/null 2>&1; then
  echo "APK ya firmado por Gradle: $FINAL"
else
  # shellcheck disable=SC1090
  source "$PASS_FILE"
  export TETHER_STOREPASS="$STOREPASS"
  "$BT/zipalign" -f 4 "$UNSIGNED" "$OUT/app-universal-release-aligned.apk"
  "$BT/apksigner" sign \
    --ks "$KEYSTORE" --ks-pass env:TETHER_STOREPASS --ks-key-alias tether \
    --out "$FINAL" "$OUT/app-universal-release-aligned.apk"
  unset TETHER_STOREPASS
  rm -f "$OUT/app-universal-release-aligned.apk"
fi

"$BT/apksigner" verify --print-certs "$FINAL" | head -3
"$BT/aapt" dump badging "$FINAL" | head -1
ls -la "$FINAL"
