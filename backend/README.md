# CircleToSearch Backend

Translation backend for the macOS app.

## What it does

- Accepts OCR text blocks from the app.
- Calls Google Cloud Translation.
- Uses Basic API-key mode for the simplest local setup.
- Uses Advanced v3 with the EU endpoint when you intentionally choose the service-account path.
- Returns translated blocks in the same order and with the same ids.

## Recommended local setup

For normal repo development:

1. Copy `.env.example` to `.env`
2. Set `GOOGLE_TRANSLATE_API_KEY`
3. Leave `TRANSLATE_SHARED_SECRET` blank
4. Leave `GOOGLE_ACCESS_TOKEN` blank
5. Run `../script/run_backend.sh` from the repo root

That uses Google Cloud Translation Basic with an API key and avoids the managed service-account setup entirely.

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

- `GOOGLE_TRANSLATE_API_KEY` for the simple local developer flow
- `GOOGLE_CLOUD_PROJECT` only if you intentionally want the Advanced v3 service-account flow
- `GOOGLE_TRANSLATE_ENDPOINT` defaults to `translate-eu.googleapis.com` for the Advanced flow
- `GOOGLE_TRANSLATE_LOCATION` defaults to `europe-west1` for the Advanced flow
- `GOOGLE_TRANSLATE_MODEL` defaults to `general/nmt` for the Advanced flow
- `GOOGLE_TRANSLATE_BASIC_ENDPOINT` defaults to `translation.googleapis.com`
- `GOOGLE_TRANSLATE_LABELS_JSON` for static labels
- `APP_STORE_EXPECTED_BUNDLE_ID` for release receipt validation
- `APP_STORE_RECEIPT_CACHE_TTL_SECONDS` for receipt-validation cache duration
- `TRANSLATE_RATE_LIMIT_WINDOW_SECONDS` and `TRANSLATE_RATE_LIMIT_MAX_REQUESTS` for per-subject rate limiting
- `TRANSLATE_ALLOW_LOCALHOST_WITHOUT_AUTH` to allow local app requests without a token
- `TRANSLATE_SHARED_SECRET` only for protected remote/debug backend use
- `GOOGLE_ACCESS_TOKEN` only for local testing overrides

## Advanced Cloud Run setup

- Deploy the service to Cloud Run with a service account attached.
- Grant the service account `roles/cloudtranslate.user`.
- Do not ship Google credentials in the macOS client.

## Authorization modes

The backend is fail-closed for non-local traffic.

It accepts either:
- an App Store receipt header from the release app: `X-Circle-To-Search-App-Receipt`
- or an explicit debug bearer token when `TRANSLATE_SHARED_SECRET` is configured
- or a local loopback request when `TRANSLATE_ALLOW_LOCALHOST_WITHOUT_AUTH=true`

Recommended usage:
- Release/App Store builds authenticate with the app receipt.
- Local repo development can rely on loopback requests.
- Remote/self-hosted use should configure `TRANSLATE_SHARED_SECRET`.

## Notes

- This service uses `translateText`, not `batchTranslateText`.
- Requests are chunked to keep them around 5K code points for latency.
- Batch translation in Google is an offline long-running operation and is not used here.
- App Store receipt validation is checked against Apple production first and retried against sandbox when Apple indicates the receipt belongs there.
- If `GOOGLE_TRANSLATE_API_KEY` is set, the backend uses Google Cloud Translation Basic for the simplest self-hosted setup.
- If `GOOGLE_TRANSLATE_API_KEY` is not set, the backend uses the existing Advanced v3 service-account flow.
