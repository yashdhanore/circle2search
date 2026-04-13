# CircleToSearch

`CircleToSearch` is a macOS menu bar app that:

- captures the visible screen
- runs OCR locally with Vision
- translates visible text
- renders translated text back over a frozen screen overlay

This repo is currently optimized for developers working on the app locally.

## Prerequisites

- macOS 15+
- a recent Xcode with the macOS 15 SDK
- a Google Cloud project with the Cloud Translation API enabled
- a Google Translate API key
- Node.js 20+ for source builds that do not include the packaged local backend helper

## Quick Start

### Open-source source build

1. Open `CircleToSearch.xcodeproj`
2. Select the `CircleToSearch Open Source` scheme
3. Build and run the app
4. Open Settings
5. Paste your Google Translate API key in `Run On This Mac`
6. Wait for the local backend status to turn healthy
7. Use the app

The source-build fallback starts the local backend with Node.js. If you want the open-source build to behave more like a packaged app, run:

```bash
./script/build_local_backend_helper.sh
```

Then rebuild the `CircleToSearch Open Source` scheme. That bundles a local backend helper into the app so the open-source build no longer depends on Node at runtime.

### Managed backend build

The default `CircleToSearch` scheme is the managed-backend/App Store path.

- backend URL comes from the Xcode config
- release builds use receipt-based auth
- self-host settings are hidden in release mode

Use this path only if you are working on the managed backend flow.

## Backend

The backend lives in [backend/](./backend).

Useful commands:

```bash
cd backend
npm install
npm run check
```

Local source-build fallback:

```bash
./script/run_backend.sh
```

Cloud Run deployment helper:

```bash
./script/deploy_cloud_run.sh
```

## Docs

- [docs/SELF_HOSTING.md](./docs/SELF_HOSTING.md): open-source developer setup
- [docs/XCODE_HANDOFF.md](./docs/XCODE_HANDOFF.md): Xcode-machine checklist for this repo

## Repo Layout

- `Sources/`: macOS app source
- `Resources/`: plist, entitlements, assets, packaged helper resources
- `Config/`: Xcode build configuration files
- `backend/`: translation backend
- `script/`: local build and backend helper scripts
