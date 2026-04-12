# CircleToSearch

`CircleToSearch` is a macOS menu bar utility for Circle-to-Search style workflows:

- trigger a global shortcut
- capture the currently visible screen
- OCR text locally
- translate visible text through a managed Google Cloud NMT backend
- paint translated text back over the frozen screen

## Current Milestone

This repo currently includes:

- a SwiftPM macOS app target
- a menu bar app shell with a dedicated settings window
- a Carbon-backed global hotkey
- a `ScreenCaptureKit` frozen-screen capture flow
- local `Vision` OCR for the visible screen
- in-place translation overlay rendering
- a managed translation backend under [backend/](./backend)
- project-local helper scripts for the app and backend

## Run the app

```bash
./script/build_and_run.sh
```

## Run the backend

```bash
cp backend/.env.example backend/.env
# fill in GOOGLE_CLOUD_PROJECT and any optional settings
./script/run_backend.sh
```

## Notes

- The default global shortcut is `Control-Shift-Space`.
- The app defaults to `http://127.0.0.1:8080` for the translation service during development.
- The backend uses Google Cloud Translation Advanced v3 through the EU endpoint with `general/nmt`.
- Google batch translation is not used here; the app needs synchronous low-latency translation, so the backend uses `translateText`.
