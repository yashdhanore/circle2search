# Self-Hosting CircleToSearch

This guide is for the open-source/self-hosted version of CircleToSearch.

The goal is simple:
- run your own translation backend
- keep your own Google credentials on your own machine or server
- point the app at that backend

## The easiest setup

The easiest setup is:
- run the backend on the same Mac as the app
- use a Google Cloud Translation API key
- leave the backend URL in the app at `http://127.0.0.1:8080`
- leave the access token blank unless you choose to add one

This is the recommended path for non-developers.

## What you need

1. A Google Cloud project with the Cloud Translation API enabled.
2. A Google Translate API key.
3. Node.js 20 or newer installed on your Mac.
4. The CircleToSearch source code on your Mac.

## Step 1: Prepare the backend

The easiest way is to use the included setup script.

Double-click:

- `script/setup_self_host_backend.command`

It will:
- ask for your Google Translate API key
- optionally ask for an access token
- create `backend/.env`
- install backend dependencies

If you prefer Terminal, run:

```bash
./script/setup_self_host_backend.command
```

## Step 2: Start the backend

Double-click:

- `script/start_self_host_backend.command`

Or run:

```bash
./script/start_self_host_backend.command
```

If everything is correct, the backend will start on:

- `http://127.0.0.1:8080`

Keep that Terminal window open while using the app.

## Step 3: Build the self-hosted app

Open:

- `CircleToSearch.xcodeproj`

Use the shared Xcode scheme:

- `CircleToSearch Open Source`

The self-hosted build should show a `Self-Hosted Translation Service` section in Settings.

## Step 4: Point the app to your backend

Open app Settings.

Use:
- Backend URL: `http://127.0.0.1:8080`
- Access token: leave blank if you did not create one during setup

If you did create an access token in setup, paste the same value into the app.

## Simple mode vs advanced mode

### Simple mode

Simple mode uses:
- `GOOGLE_TRANSLATE_API_KEY`
- Google Cloud Translation Basic

This is the easiest setup and is the recommended choice for most self-hosted users.

### Advanced mode

Advanced mode uses:
- `GOOGLE_CLOUD_PROJECT`
- Google Cloud Translation Advanced v3
- service-account based auth

Advanced mode is better if you specifically need:
- the Advanced v3 backend path
- IAM/service-account based auth
- the stronger managed-server configuration

It is more complex and is not the recommended first setup for non-developers.

## Notes about access tokens

If your backend only runs on your own Mac:
- you can leave the app access token blank
- the backend allows local loopback requests without extra auth

If you host the backend somewhere else:
- set an access token in `backend/.env`
- paste the same token into the app settings

## Troubleshooting

### The app says translation failed

Check:
- the backend Terminal window is still open
- the backend URL is `http://127.0.0.1:8080`
- your API key is valid
- the Cloud Translation API is enabled in your Google Cloud project

### The backend does not start

Check:
- Node.js is installed
- `backend/.env` exists
- `GOOGLE_TRANSLATE_API_KEY` is set in `backend/.env`

### I want to host the backend on another machine or server

That is supported, but it is a more advanced setup.

For that setup:
- use a non-local backend URL in the app
- set an access token
- if you want, use the existing Cloud Run deployment path instead of local hosting
