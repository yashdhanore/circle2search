#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${OPPER_API_KEY:-}" ]]; then
  echo "error: set OPPER_API_KEY before running this script" >&2
  exit 1
fi

COUNT="${1:-3}"
TARGET_LANGUAGE="${2:-Swedish}"
MODEL="${3:-${OPPER_MODEL:-openai/gpt-5.4-nano}}"
BASE_URL="${OPPER_BASE_URL:-https://api.opper.ai}"
ENDPOINT="${BASE_URL%/}/v3/call"
TMP_JSON="$(mktemp /tmp/opper-batch-request.XXXXXX.json)"
TMP_BODY="$(mktemp /tmp/opper-batch-response.XXXXXX.json)"
TMP_HEADERS="$(mktemp /tmp/opper-batch-headers.XXXXXX.txt)"

cleanup() {
  rm -f "$TMP_JSON" "$TMP_BODY" "$TMP_HEADERS"
}
trap cleanup EXIT

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -le 0 ]]; then
  echo "error: count must be a positive integer" >&2
  exit 1
fi

COUNT="$COUNT" TARGET_LANGUAGE="$TARGET_LANGUAGE" MODEL="$MODEL" python3 <<'PY' >"$TMP_JSON"
import json
import os

count = int(os.environ["COUNT"])
target_language = os.environ["TARGET_LANGUAGE"]
model = os.environ["MODEL"]

items = [
    {
        "id": f"item-{index + 1}",
        "text": f"Translate this sample sentence number {index + 1} into {target_language}.",
    }
    for index in range(count)
]

payload = {
    "name": "circle_to_search_translate_batch_test",
    "model": model,
    "instructions": (
        f"Translate each item's text into {target_language}. "
        "Return one translation result per input item. "
        "Preserve each item's id exactly as provided. "
        "Keep the same ordering when practical. "
        "Return only the translated text for each item."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "items": {
                "type": "array",
                "description": "Ordered items to translate",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "text": {"type": "string"},
                    },
                    "required": ["id", "text"],
                },
            }
        },
        "required": ["items"],
    },
    "output_schema": {
        "type": "object",
        "properties": {
            "translations": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "id": {"type": "string"},
                        "translation": {"type": "string"},
                        "detected_source_language": {"type": "string"},
                    },
                    "required": ["id", "translation"],
                },
            }
        },
        "required": ["translations"],
    },
    "input": {
        "items": items,
    },
}

print(json.dumps(payload))
PY

echo "POST $ENDPOINT"
echo "Items: $COUNT"
echo "Target language: $TARGET_LANGUAGE"
echo "Model: $MODEL"
echo

HTTP_STATUS="$(
  curl -sS "$ENDPOINT" \
    -H "Authorization: Bearer $OPPER_API_KEY" \
    -H "Content-Type: application/json" \
    --data @"$TMP_JSON" \
    -D "$TMP_HEADERS" \
    -o "$TMP_BODY" \
    -w "%{http_code}"
)"

echo "HTTP $HTTP_STATUS"
echo
cat "$TMP_HEADERS"
echo
cat "$TMP_BODY"
echo
