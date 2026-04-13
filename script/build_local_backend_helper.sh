#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
RUNTIME_DIR="$ROOT_DIR/Resources/OpenSourceRuntime"
BUILD_DIR="$ROOT_DIR/.build/local-backend-helper"
OUTPUT_BINARY="$RUNTIME_DIR/circle2search-local-backend"
SEA_CONFIG="$BUILD_DIR/sea-config.json"
BUNDLED_SCRIPT="$BUILD_DIR/server.bundle.cjs"

required_major=25

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 25.5 or newer is required to build the packaged local backend helper." >&2
  exit 1
fi

node_major="$(node -p "process.versions.node.split('.')[0]")"
if [[ "$node_major" -lt "$required_major" ]]; then
  echo "Node.js 25.5 or newer is required. Current major version: $node_major" >&2
  exit 1
fi

mkdir -p "$BUILD_DIR" "$RUNTIME_DIR"

cd "$BACKEND_DIR"

if [[ ! -d node_modules ]]; then
  echo "Installing backend dependencies..."
  npm install
fi

if [[ ! -x node_modules/.bin/esbuild ]]; then
  echo "esbuild is missing from backend dependencies. Run npm install in backend/ first." >&2
  exit 1
fi

echo "Bundling backend sources..."
node_modules/.bin/esbuild src/server.js \
  --bundle \
  --platform=node \
  --format=cjs \
  --target=node25 \
  --outfile="$BUNDLED_SCRIPT"

cat >"$SEA_CONFIG" <<EOF
{
  "main": "$BUNDLED_SCRIPT",
  "output": "$OUTPUT_BINARY",
  "disableExperimentalSEAWarning": true
}
EOF

echo "Building packaged local backend runtime..."
node --build-sea "$SEA_CONFIG"
chmod +x "$OUTPUT_BINARY"

echo
echo "Packaged local backend runtime created:"
echo "$OUTPUT_BINARY"
echo
echo "Next step:"
echo "Build or archive the 'CircleToSearch Open Source' app so this runtime is copied into the app bundle."
