#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/backend/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "backend/.env is missing."
  echo "Run script/setup_self_host_backend.command first."
  exit 1
fi

exec "$ROOT_DIR/script/run_backend.sh"
