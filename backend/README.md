# CircleToSearch Backend

Managed translation service for the macOS app.

## What it does

- Accepts OCR text blocks from the app.
- Calls Google Cloud Translation Advanced v3.
- Uses the EU regional endpoint.
- Uses the `general/nmt` model for low-latency translation.
- Returns translated blocks in the same order and with the same ids.

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
- `TRANSLATE_SHARED_SECRET` to require a bearer token
- `GOOGLE_ACCESS_TOKEN` only for local testing overrides

## Google Cloud setup

- Deploy the service to Cloud Run with a service account attached.
- Grant the service account `roles/cloudtranslate.user`.
- Do not ship Google credentials in the macOS client.

## Notes

- This service uses `translateText`, not `batchTranslateText`.
- Requests are chunked to keep them around 5K code points for latency.
- Batch translation in Google is an offline long-running operation and is not used here.
