# Open Source Developer Setup

This document is for developers running the `CircleToSearch Open Source` scheme from this repo.

## What You Need

- macOS 15+
- a recent Xcode with the macOS 15 SDK
- a Google Cloud project with the Cloud Translation API enabled
- a Google Translate API key
- Node.js 20+

## Quick Start

1. Install backend dependencies:

```bash
cd backend
npm install
cp .env.example .env
```

2. Edit `backend/.env` and set:

```bash
GOOGLE_TRANSLATE_API_KEY=your_key_here
```

For normal local development:
- leave `TRANSLATE_SHARED_SECRET` blank
- leave `GOOGLE_ACCESS_TOKEN` blank
- leave the rest of the advanced settings alone unless you are intentionally using Cloud Run or the managed service-account flow

3. From the repo root, start the backend:

```bash
./script/run_backend.sh
```

4. Open `CircleToSearch.xcodeproj`
5. Select `CircleToSearch Open Source`
6. Build and run
7. Open Settings
8. Click `Check Status`
9. Use the app

## Advanced Remote Backend

The `Advanced` section in Settings is only for remote or custom backend setups.

Use it if you want to:
- point the app at a backend running on another machine
- point the app at Cloud Run
- use an access token for a protected backend

For normal local development, leave the app pointed at `http://127.0.0.1:8080` and keep the access token empty.

## Backend Commands

Backend validation:

```bash
cd backend
npm install
npm run check
```

Manual local backend run:

```bash
./script/run_backend.sh
```

## Troubleshooting

### The app says it could not connect to the server

Check:
- `./script/run_backend.sh` is still running in a Terminal window
- `backend/.env` contains a valid `GOOGLE_TRANSLATE_API_KEY`
- `npm install` completed in `backend/`
- Settings still point to `http://127.0.0.1:8080`

### The app says translation failed

Check:
- your Google API key is valid
- Cloud Translation API is enabled on your Google Cloud project
- the local backend status in Settings is healthy
