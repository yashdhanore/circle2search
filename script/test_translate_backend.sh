#!/usr/bin/env bash

set -euo pipefail

BASE_URL="${1:-http://127.0.0.1:8080}"
TARGET_LANGUAGE_CODE="${2:-sv}"
AUTH_HEADER=""

if [[ -n "${TRANSLATE_SHARED_SECRET:-}" ]]; then
  AUTH_HEADER="Authorization: Bearer ${TRANSLATE_SHARED_SECRET}"
fi

PAYLOAD_FILE="$(mktemp)"
trap 'rm -f "$PAYLOAD_FILE"' EXIT

cat >"$PAYLOAD_FILE" <<JSON
{
  "targetLanguageCode": "$TARGET_LANGUAGE_CODE",
  "blocks": [
    { "id": "block-1", "text": "File" },
    { "id": "block-2", "text": "Edit" },
    { "id": "block-3", "text": "View" }
  ]
}
JSON

echo "POST ${BASE_URL%/}/v1/translate-screen"
echo "Target language: $TARGET_LANGUAGE_CODE"
echo

if [[ -n "$AUTH_HEADER" ]]; then
  curl -i "${BASE_URL%/}/v1/translate-screen" \
    -H "Content-Type: application/json" \
    -H "$AUTH_HEADER" \
    --data @"$PAYLOAD_FILE"
else
  curl -i "${BASE_URL%/}/v1/translate-screen" \
    -H "Content-Type: application/json" \
    --data @"$PAYLOAD_FILE"
fi
