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

if [[ -z "${GOOGLE_CLOUD_PROJECT:-}" ]]; then
  echo "GOOGLE_CLOUD_PROJECT must be set in backend/.env or the shell environment." >&2
  exit 1
fi

cd "$BACKEND_DIR"
exec npm start
