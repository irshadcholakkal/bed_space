#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep CI aligned with the Flutter SDK used to validate this project.
FLUTTER_VERSION="$(node scripts/load-build-env.mjs --flutter-version)"
if [[ ! "$FLUTTER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'FLUTTER_VERSION must be an exact stable version, for example 3.47.2.' >&2
  exit 1
fi
node scripts/load-build-env.mjs --require-supabase

SDK_DIR="${TMPDIR:-/tmp}/bed-space-flutter-${FLUTTER_VERSION}"
if [[ ! -x "$SDK_DIR/bin/flutter" ]]; then
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$SDK_DIR"
fi
export PATH="$SDK_DIR/bin:$PATH"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true
export DART_SUPPRESS_ANALYTICS=true

flutter --version
flutter config --no-analytics
flutter pub get --enforce-lockfile
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn --base-href /app/ \
  --dart-define-from-file=.dart_tool/build-config.json
node scripts/prepare_pwa.mjs
npm ci --prefix landing --no-audit --no-fund
npm run build --prefix landing
node scripts/assemble-site.mjs
