#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

if [[ ! -d "$BACKEND_DIR" ]]; then
  echo "Backend directory not found: $BACKEND_DIR" >&2
  exit 1
fi

if [[ -f "$BACKEND_DIR/.env" ]]; then
  set -a
  source "$BACKEND_DIR/.env"
  set +a
fi

if [[ -z "${GOOGLE_TRANSLATE_API_KEY:-}" && -z "${GOOGLE_CLOUD_PROJECT:-}" ]]; then
  echo "Set GOOGLE_TRANSLATE_API_KEY for the simple self-host setup, or GOOGLE_CLOUD_PROJECT for the advanced service-account setup." >&2
  exit 1
fi

cd "$BACKEND_DIR"

if [[ ! -d node_modules ]]; then
  echo "Installing backend dependencies..."
  npm install
fi

exec npm start
