# Self-Hosting CircleToSearch

This guide is for the open-source/self-hosted version of CircleToSearch.

The recommended setup is now the simple local flow:

1. Open the `CircleToSearch Open Source` app.
2. Open Settings.
3. Paste your Google Translate API key once.
4. Click `Start Local Backend`.
5. Wait for the status to say the backend is running.
6. Use the app.

CircleToSearch will then talk to a translation backend running on the same Mac at `http://127.0.0.1:8080`.

This is the recommended path for non-developers.

## What you need

1. A Google Cloud project with the Cloud Translation API enabled.
2. A Google Translate API key.
3. Node.js 20 or newer installed on your Mac.

## The easiest setup

Use the `Run On This Mac` section in Settings.

What it does:
- stores your Google API key in macOS Keychain
- copies the bundled backend files into Application Support
- starts the local backend on your Mac
- keeps CircleToSearch pointed at `http://127.0.0.1:8080`

In the simple local mode, you do not need to type a backend URL or token.

## If Node.js is missing

The app will tell you that Node.js 20 or newer is required.

Install Node.js, then return to Settings and click `Start Local Backend` again.

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
- a backend process running on the same Mac as the app

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
- the app handles the local setup for you

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
- Node.js is installed
- you pasted a Google API key in Settings
- the app shows `Local backend is running on this Mac`

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
3. Build and run the app
4. Use the same in-app `Run On This Mac` flow described above

The old setup and start scripts are still in `script/` for manual backend work, but they are no longer the recommended first path for normal open-source users.
