# CircleToSearch Backend

Managed translation service for the macOS app.

## What it does

- Accepts OCR text blocks from the app.
- Calls Google Cloud Translation Advanced v3.
- Uses the EU regional endpoint.
- Uses the `general/nmt` model for low-latency translation.
- Returns translated blocks in the same order and with the same ids.
- Requires authorization for every translation request.

## API

### `POST /v1/translate-screen`

Request:

```json
{
  "targetLanguageCode": "sv",
  "sourceLanguageCode": "en",
  "blocks": [
    { "id": "block-1", "text": "File" },
    { "id": "block-2", "text": "Edit" }
  ],
  "labels": {
    "screen_mode": "translate"
  }
}
```

Response:

```json
{
  "provider": "google-cloud-nmt",
  "region": "europe-west1",
  "blocks": [
    { "id": "block-1", "translatedText": "Arkiv", "detectedSourceLanguage": "en" },
    { "id": "block-2", "translatedText": "Redigera", "detectedSourceLanguage": "en" }
  ]
}
```

## Environment

Copy `.env.example` and set:

- `GOOGLE_CLOUD_PROJECT`
- `GOOGLE_TRANSLATE_ENDPOINT` defaults to `translate-eu.googleapis.com`
- `GOOGLE_TRANSLATE_LOCATION` defaults to `europe-west1`
- `GOOGLE_TRANSLATE_MODEL` defaults to `general/nmt`
- `GOOGLE_TRANSLATE_LABELS_JSON` for static labels
- `APP_STORE_EXPECTED_BUNDLE_ID` for release receipt validation
- `APP_STORE_RECEIPT_CACHE_TTL_SECONDS` for receipt-validation cache duration
- `TRANSLATE_RATE_LIMIT_WINDOW_SECONDS` and `TRANSLATE_RATE_LIMIT_MAX_REQUESTS` for per-subject rate limiting
- `TRANSLATE_SHARED_SECRET` for explicit debug bearer auth
- `GOOGLE_ACCESS_TOKEN` only for local testing overrides

## Google Cloud setup

- Deploy the service to Cloud Run with a service account attached.
- Grant the service account `roles/cloudtranslate.user`.
- Do not ship Google credentials in the macOS client.

## Authorization modes

The backend is fail-closed.

It accepts either:
- an App Store receipt header from the release app: `X-Circle-To-Search-App-Receipt`
- or an explicit debug bearer token when `TRANSLATE_SHARED_SECRET` is configured

Recommended usage:
- Release/App Store builds authenticate with the app receipt.
- Local development uses `TRANSLATE_SHARED_SECRET`.

## Notes

- This service uses `translateText`, not `batchTranslateText`.
- Requests are chunked to keep them around 5K code points for latency.
- Batch translation in Google is an offline long-running operation and is not used here.
- App Store receipt validation is checked against Apple production first and retried against sandbox when Apple indicates the receipt belongs there.
