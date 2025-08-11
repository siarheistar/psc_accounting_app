#!/usr/bin/env bash
set -euo pipefail

# One-command deploy for Flutter Web to Firebase Hosting
# Requirements: flutter, node/npm, firebase-tools installed and logged in

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not found. Install Flutter SDK first." >&2
  exit 1
fi

if ! command -v firebase >/dev/null 2>&1; then
  echo "Firebase CLI not found. Install with: npm install -g firebase-tools" >&2
  exit 1
fi

# Build web (optionally inject API base URL)
flutter pub get
if [[ -n "${API_BASE_URL:-}" ]]; then
  echo "Building Flutter web with API_BASE_URL=$API_BASE_URL"
  flutter build web --dart-define=API_BASE_URL="$API_BASE_URL"
else
  echo "Building Flutter web with default API_BASE_URL (http://127.0.0.1:8000)"
  flutter build web
fi

# Ensure firebase project is selected; allow override via env
if [[ -n "${FIREBASE_PROJECT:-}" ]]; then
  firebase use "$FIREBASE_PROJECT" || firebase use --add "$FIREBASE_PROJECT"
fi

# Deploy hosting only
firebase deploy --only hosting
