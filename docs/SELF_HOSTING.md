# Open Source Developer Setup

This document is for developers running the `CircleToSearch Open Source` scheme from this repo.

## What You Need

- macOS 15+
- a recent Xcode with the macOS 15 SDK
- a Google Cloud project with the Cloud Translation API enabled
- a Google Translate API key
- Node.js 20+ for source builds without the packaged helper runtime

## Fastest Path

1. Open `CircleToSearch.xcodeproj`
2. Select `CircleToSearch Open Source`
3. Build and run
4. Open Settings
5. Paste your Google Translate API key into `Run On This Mac`
6. Wait for the local backend status to become healthy
7. Use the app

If the build does not include the packaged local backend helper, the app falls back to Node.js for the local backend.

## Optional: Build The Packaged Local Backend Helper

If you want the open-source build to run without Node at runtime, generate the local backend helper before building the app:

```bash
./script/build_local_backend_helper.sh
```

That creates:

- `Resources/OpenSourceRuntime/circle2search-local-backend`

Then rebuild `CircleToSearch Open Source`.

Use this when:
- preparing a shareable open-source app build
- testing the packaged-helper path

You do not need it for normal source-level development if Node.js is installed.

## Advanced Remote Backend

The `Advanced` section in Settings is only for remote or custom backend setups.

Use it if you want to:
- point the app at a backend running on another machine
- point the app at Cloud Run
- use an access token for a protected backend

For normal local development, keep using `Run On This Mac`.

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

Cloud Run deployment helper:

```bash
./script/deploy_cloud_run.sh
```

## Troubleshooting

### The app says Node.js is required

This means your source build does not include the packaged local backend helper.

Fix either by:
- installing Node.js 20+, or
- running `./script/build_local_backend_helper.sh` and rebuilding

### The app says translation failed

Check:
- your Google API key is valid
- Cloud Translation API is enabled on your Google Cloud project
- the local backend status in Settings is healthy

### I want to inspect the local backend files

Use the `Advanced` section in Settings and click `Open Local Backend Folder`.
