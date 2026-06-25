#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
BACKEND_PORT="${BACKEND_PORT:-3000}"
FLUTTER_DEVICE="${FLUTTER_DEVICE:-macos}"
EXTERNAL_BUILD_DIR="${EXTERNAL_BUILD_DIR:-/tmp/lightmapz_flutter_build}"
BACKEND_PID=""

cleanup() {
  if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo
    echo "Stoppe Backend..."
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

backend_health_url="http://127.0.0.1:${BACKEND_PORT}/health"

echo "Starte LightMapz Entwicklungsumgebung"
echo "Backend: $backend_health_url"
echo "Flutter-Geraet: $FLUTTER_DEVICE"
echo

if curl -fsS "$backend_health_url" >/dev/null 2>&1; then
  echo "Backend laeuft bereits auf Port $BACKEND_PORT."
else
  echo "Installiere und baue Backend..."
  (
    cd "$BACKEND_DIR"
    npm install
    npm run build
    PORT="$BACKEND_PORT" exec node dist/server.js
  ) &
  BACKEND_PID="$!"

  echo "Warte auf Backend..."
  for _ in {1..30}; do
    if curl -fsS "$backend_health_url" >/dev/null 2>&1; then
      echo "Backend ist bereit."
      break
    fi

    if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
      echo "Backend ist beim Starten beendet worden."
      wait "$BACKEND_PID" 2>/dev/null || true
      exit 1
    fi

    sleep 1
  done

  if ! curl -fsS "$backend_health_url" >/dev/null 2>&1; then
    echo "Backend wurde nicht rechtzeitig erreichbar."
    exit 1
  fi
fi

echo
echo "Starte Flutter-App..."
cd "$ROOT_DIR"

echo "Entferne macOS-CodeSign-Metadaten..."
find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -name '._*' -delete
find "$ROOT_DIR" -path "$ROOT_DIR/.git" -prune -o -name '.DS_Store' -delete

for attr in \
  com.apple.FinderInfo \
  com.apple.ResourceFork \
  com.apple.quarantine \
  'com.apple.fileprovider.fpfs#P' \
  'com.apple.fileprovider.dir#N'; do
  find "$ROOT_DIR/macos" "$ROOT_DIR/build" \
    -xattrname "$attr" \
    -exec xattr -d "$attr" {} \; 2>/dev/null || true
done

for path in \
  "$ROOT_DIR/macos" \
  "$ROOT_DIR/ios" \
  "$ROOT_DIR/android" \
  "$ROOT_DIR/lib" \
  "$ROOT_DIR/web" \
  "$ROOT_DIR/pubspec.yaml" \
  "$ROOT_DIR/pubspec.lock"; do
  if [[ -e "$path" ]]; then
    xattr -cr "$path" 2>/dev/null || true
  fi
done

rm -rf "$ROOT_DIR/build/macos"

if [[ "$FLUTTER_DEVICE" == "macos" ]]; then
  echo "Nutze externen macOS-Buildordner: $EXTERNAL_BUILD_DIR"
  rm -f "$ROOT_DIR/build 2" "$ROOT_DIR/build 3"
  if [[ -L "$ROOT_DIR/build" ]]; then
    unlink "$ROOT_DIR/build"
  else
    rm -rf "$ROOT_DIR/build"
  fi
  rm -rf "$EXTERNAL_BUILD_DIR"
  mkdir -p "$EXTERNAL_BUILD_DIR"
  ln -s "$EXTERNAL_BUILD_DIR" "$ROOT_DIR/build"
fi

flutter pub get

if [[ "$FLUTTER_DEVICE" == "macos" ]]; then
  flutter build macos --debug

  APP_PATH="$ROOT_DIR/build/macos/Build/Products/Debug/lightmapz.app"
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Die macOS-App wurde nicht gefunden: $APP_PATH"
    exit 1
  fi

  xattr -cr "$APP_PATH" 2>/dev/null || true
  find "$APP_PATH" -name '._*' -delete
  find "$APP_PATH" -name '.DS_Store' -delete
  codesign --force --deep --sign - \
    --entitlements "$ROOT_DIR/macos/Runner/DebugProfile.entitlements" \
    "$APP_PATH"

  echo
  echo "Oeffne LightMapz. Beende die App, um auch das Backend zu stoppen."
  open -n -W "$APP_PATH"
else
  flutter run -d "$FLUTTER_DEVICE"
fi
