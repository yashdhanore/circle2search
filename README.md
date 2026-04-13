# CircleToSearch

`CircleToSearch` is a macOS menu bar utility for Circle-to-Search style workflows:

- trigger a global shortcut
- capture the currently visible screen
- OCR text locally
- translate visible text through a managed Google Cloud NMT backend
- paint translated text back over the frozen screen

## Current Milestone

This repo currently includes:

- a SwiftPM-first macOS app target
- a real Xcode macOS app project at `CircleToSearch.xcodeproj`
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

For Xcode builds, open `CircleToSearch.xcodeproj` and run the `CircleToSearch` macOS app scheme.

## Run the backend

```bash
cp backend/.env.example backend/.env
# fill in GOOGLE_CLOUD_PROJECT and any optional settings
./script/run_backend.sh
```

## Self-hosted open-source setup

The recommended open-source flow is now:

1. Build or download the `CircleToSearch Open Source` app
2. Open Settings
3. Paste your Google Translate API key once
4. Wait while CircleToSearch starts the local backend automatically
5. Use the app

In Xcode, the shared open-source scheme is:

- `CircleToSearch Open Source`

Maintainers packaging the open-source app should also run:

```bash
./script/build_local_backend_helper.sh
```

The old setup and start scripts are still available for manual backend work and fallback source-build scenarios:

```bash
./script/setup_self_host_backend.command
./script/start_self_host_backend.command
```

Detailed instructions:

- [docs/SELF_HOSTING.md](./docs/SELF_HOSTING.md)

## Notes

- The default global shortcut is `Control-Shift-Space`.
- The app defaults to `http://127.0.0.1:8080` for the translation service during development.
- Release builds read the managed translation endpoint from the Xcode build configuration via `ManagedTranslationBaseURL`.
- The backend uses Google Cloud Translation Advanced v3 through the EU endpoint with `general/nmt`.
- Google batch translation is not used here; the app needs synchronous low-latency translation, so the backend uses `translateText`.
