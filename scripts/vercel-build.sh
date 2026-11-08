#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Keep CI aligned with the Flutter SDK used to validate this project.
FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.2}"
if [[ ! "$FLUTTER_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'FLUTTER_VERSION must be an exact stable version, for example 3.47.2.' >&2
  exit 1
fi
if [[ -z "${GOOGLE_CLIENT_ID:-}" ]]; then
  echo 'Set GOOGLE_CLIENT_ID in Vercel Environment Variables to your Google web OAuth client ID, then redeploy.' >&2
  exit 1
fi

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
flutter build web --release --no-web-resources-cdn --base-href / \
  "--dart-define=GOOGLE_CLIENT_ID=$GOOGLE_CLIENT_ID"
node scripts/prepare_pwa.mjs
