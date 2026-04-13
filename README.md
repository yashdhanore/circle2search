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
- Node.js 20+

## Quick Start

1. Install backend dependencies:

```bash
cd backend
npm install
cp .env.example .env
```

2. Edit `backend/.env` and set only:

```bash
GOOGLE_TRANSLATE_API_KEY=your_key_here
```

For normal local development, leave the shared secret and access token settings blank.

3. Start the backend from the repo root:

```bash
./script/run_backend.sh
```

4. Open `CircleToSearch.xcodeproj`
5. Select the `CircleToSearch Open Source` scheme
6. Build and run the app
7. Open Settings and click `Check Status`
8. Use the app

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

## Docs

- [docs/SELF_HOSTING.md](./docs/SELF_HOSTING.md): open-source developer setup
- [docs/XCODE_HANDOFF.md](./docs/XCODE_HANDOFF.md): Xcode-machine checklist for this repo

## Repo Layout

- `Sources/`: macOS app source
- `Resources/`: plist, entitlements, assets, packaged helper resources
- `Config/`: Xcode build configuration files
- `backend/`: translation backend
- `script/`: local build and backend helper scripts
