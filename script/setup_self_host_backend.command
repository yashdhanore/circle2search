#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
ENV_FILE="$BACKEND_DIR/.env"

echo "CircleToSearch self-hosted backend setup"
echo
echo "This is the easiest setup."
echo "You only need a Google Cloud Translation API key."
echo

if [[ -f "$ENV_FILE" ]]; then
  read -r -p "A backend/.env file already exists. Replace it? [y/N] " REPLACE_ENV
  if [[ ! "$REPLACE_ENV" =~ ^[Yy]$ ]]; then
    echo "Keeping the existing backend/.env file."
    exit 0
  fi
fi

read -r -p "Paste your Google Translate API key: " GOOGLE_TRANSLATE_API_KEY

if [[ -z "$GOOGLE_TRANSLATE_API_KEY" ]]; then
  echo "A Google Translate API key is required." >&2
  exit 1
fi

read -r -p "Optional access token for the app (press Enter to skip): " TRANSLATE_SHARED_SECRET

cat >"$ENV_FILE" <<EOF
PORT=8080
GOOGLE_TRANSLATE_API_KEY=$GOOGLE_TRANSLATE_API_KEY
GOOGLE_TRANSLATE_BASIC_ENDPOINT=translation.googleapis.com
GOOGLE_TRANSLATE_LABELS_JSON={"app":"circle2search","surface":"screen_translate"}
TRANSLATE_ALLOW_LOCALHOST_WITHOUT_AUTH=true
TRANSLATE_SHARED_SECRET=$TRANSLATE_SHARED_SECRET
EOF

echo
echo "Installing backend dependencies..."
cd "$BACKEND_DIR"
npm install

echo
echo "Setup complete."
echo
echo "Next steps:"
echo "1. Start the backend by double-clicking script/start_self_host_backend.command"
echo "2. Build or run the Open Source app configuration"
echo "3. In app settings, leave the backend URL at http://127.0.0.1:8080"
if [[ -n "$TRANSLATE_SHARED_SECRET" ]]; then
  echo "4. Paste the same access token into the app settings"
else
  echo "4. Leave the access token blank"
fi
