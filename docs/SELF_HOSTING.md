# Self-Hosting CircleToSearch

This guide is for the open-source/self-hosted version of CircleToSearch.

The recommended setup is now the simple local flow:

1. Open the `CircleToSearch Open Source` app.
2. Open Settings.
3. Paste your Google Translate API key once.
4. Wait a moment while CircleToSearch starts the local backend automatically.
5. Wait for the status to say the backend is running.
6. Use the app.

CircleToSearch will then talk to a translation backend running on the same Mac at `http://127.0.0.1:8080`.

This is the recommended path for non-developers.

## What you need

1. A Google Cloud project with the Cloud Translation API enabled.
2. A Google Translate API key.
3. A packaged `CircleToSearch Open Source` app that already includes the local backend runtime.

## The easiest setup

Use the `Run On This Mac` section in Settings.

What it does:
- stores your Google API key in macOS Keychain
- starts the bundled local backend on your Mac automatically
- keeps CircleToSearch pointed at `http://127.0.0.1:8080`

In the simple local mode, you do not need to type a backend URL or token.

## What normal users should download

Normal users should download a packaged `CircleToSearch Open Source.app`.

That packaged app should already include the local backend runtime.

Normal users should not need:
- Node.js
- Terminal setup
- backend scripts
- manual backend start buttons

## If you built the app from source instead of downloading a packaged app

A source build may not include the packaged local backend runtime yet.

In that case, CircleToSearch may tell you that Node.js is required.

That is expected for a source build until the maintainer packages the local backend runtime into the app bundle.

## Advanced mode

The `Advanced` section in Settings is only for users who host the backend somewhere other than the same Mac.

Use that only if you want to:
- run the backend on another machine
- run the backend on Cloud Run
- protect a remote backend with an access token

## Simple mode vs advanced mode

### Simple local mode

Simple local mode uses:
- your Google Translate API key
- Google Cloud Translation Basic
- a bundled local backend process running on the same Mac as the app

This is the easiest setup and the recommended path for most open-source users.

### Advanced self-hosted mode

Advanced self-hosted mode is still available if you want to run the backend yourself outside the app.

That path supports:
- a remote backend URL
- an optional access token
- the existing Cloud Run deployment flow
- the Advanced v3 service-account setup

## Notes about access tokens

If your backend runs only on your own Mac:
- you can leave the access token blank
- the app handles the local startup for you

If you host the backend somewhere else:
- set an access token on that backend
- paste the same token into the app `Advanced` settings

## Troubleshooting

### The app says translation failed

Check:
- the local backend status says it is running
- your API key is valid
- the Cloud Translation API is enabled in your Google Cloud project

### The local backend does not start

Check:
- you pasted a Google API key in Settings
- the app shows `Local backend is running on this Mac`

If you are using a source build instead of a packaged Open Source app:
- the packaged local backend runtime may not be bundled yet
- Node.js may still be required for that source build

### I want to host the backend on another machine or server

That is supported, but it is a more advanced setup.

For that setup:
- use a non-local backend URL in the app `Advanced` section
- set an access token
- if you want, use the existing Cloud Run deployment path instead of local hosting

## Developer / source-build flow

If you are building the app from source in Xcode:

1. Open `CircleToSearch.xcodeproj`
2. Use the shared scheme `CircleToSearch Open Source`
3. Run `./script/build_local_backend_helper.sh`
4. Build and run the app
5. Use the same in-app `Run On This Mac` flow described above

The old setup and start scripts are still in `script/` for manual backend work, but they are no longer the recommended first path for normal open-source users.
