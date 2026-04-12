# CircleToSearch Xcode Handoff

This document is the release and validation handoff for the Xcode-enabled machine.

Current repo state:
- The app is functional as a SwiftPM macOS menu bar utility.
- Local OCR is on-device with Vision.
- Translation goes through the managed Google Cloud Translation backend.
- Debug-only backend URL and bearer token controls exist in Settings.
- The app is not yet packaged for Mac App Store distribution.

This machine constraint is important:
- The current development machine does not have usable Xcode access.
- Xcode-specific work must be done on another machine.
- Anything involving archives, signing, entitlements, sandbox behavior, TestFlight, or App Store submission must be validated on the Xcode machine.

## Current Good State

These parts are already in the right direction and should be preserved:

- Runtime config split between debug and release:
  - [AppRuntimeConfiguration.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Support/AppRuntimeConfiguration.swift)
- Debug-only backend controls in Settings:
  - [SettingsView.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Views/SettingsView.swift)
- Debug bearer token stored in Keychain instead of `UserDefaults`:
  - [ManagedTranslationDebugStore.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Models/ManagedTranslationDebugStore.swift)
  - [KeychainStore.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Services/KeychainStore.swift)
- Simplified user-facing translation preference:
  - `Always Translate To` in [SettingsView.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Views/SettingsView.swift)
- Managed translation provider path:
  - [TranslationProvider.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Services/TranslationProvider.swift)
- Google Cloud backend:
  - [backend/src/server.js](/Users/ydh0rs/Desktop/Personal/circle2search/backend/src/server.js)
  - [backend/src/config.js](/Users/ydh0rs/Desktop/Personal/circle2search/backend/src/config.js)
  - [script/deploy_cloud_run.sh](/Users/ydh0rs/Desktop/Personal/circle2search/script/deploy_cloud_run.sh)

## Must Fix Before App Store Release

### 1. Backend auth is not production-safe yet

Current issue:
- The backend accepts requests when `TRANSLATE_SHARED_SECRET` is unset.
- This is implemented in [server.js](/Users/ydh0rs/Desktop/Personal/circle2search/backend/src/server.js) in `authorizeRequest`.
- The deploy script still uses `--allow-unauthenticated` in [deploy_cloud_run.sh](/Users/ydh0rs/Desktop/Personal/circle2search/script/deploy_cloud_run.sh).

Why this matters:
- A public Mac App Store client cannot safely hold a permanent shared backend secret.
- If left as-is, the backend is a paid public proxy and is vulnerable to abuse and unexpected cost.

What needs to change:
- Do not ship with fail-open backend auth.
- Remove the path where missing `TRANSLATE_SHARED_SECRET` means allow all requests.
- Replace static shared-secret auth with a stronger production mechanism.

Minimum acceptable production direction:
- Server-enforced auth for every request.
- Rate limiting.
- Per-install or per-account identity.
- Short-lived server-issued tokens or server-side validation.

Pragmatic near-term options:
- If you need a short bridge to TestFlight only, require a server-side secret and keep distribution limited.
- For actual App Store release, move to a real server-issued auth flow.

### 2. Release backend URL must not stay hardcoded in source

Current issue:
- The release backend URL is still a source constant in [AppRuntimeConfiguration.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Support/AppRuntimeConfiguration.swift).

Why this matters:
- Release endpoint changes should be build configuration, not source edits.
- App Store builds need deterministic release config.

What needs to change on the Xcode machine:
- Move the production endpoint into a release build setting or `Info.plist` value.
- Keep debug override behavior for debug builds only.
- Release builds should read a fixed, non-editable endpoint from bundle config.

Recommended shape:
- `DEBUG`:
  - local Cloud Run URL override allowed
  - debug token field visible
- `RELEASE`:
  - fixed production URL from build config
  - no debug override UI
  - no bearer token field in settings

### 3. Real macOS app target and packaging path are still missing

Current issue:
- The repo is currently SwiftPM-first:
  - [Package.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Package.swift)
- The local app bundle is synthesized by:
  - [build_and_run.sh](/Users/ydh0rs/Desktop/Personal/circle2search/script/build_and_run.sh)

Why this matters:
- That script is good for local development only.
- It does not define a real App Store archive path.
- It does not solve entitlements, sandbox, privacy manifest integration, asset catalogs, or signing configuration.

What needs to be created on the Xcode machine:
- A real macOS app target.
- An asset catalog with app icons.
- Build settings for versioning and bundle IDs.
- App Sandbox entitlements.
- Privacy manifest.
- Archive and TestFlight path.

## Xcode Machine Work Plan

### Step 1. Create the Xcode app target

Goal:
- Keep the existing source layout.
- Wrap it in a real macOS app target.

Recommended approach:
- Create a new macOS App project in Xcode.
- Reuse the existing `Sources/` files instead of rewriting the app.
- Keep the folder structure:
  - `Sources/App`
  - `Sources/Models`
  - `Sources/Services`
  - `Sources/Support`
  - `Sources/Views`

What to preserve:
- `@main` app entry in [CircleToSearchApp.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/App/CircleToSearchApp.swift)
- the existing AppKit bridge points
- settings window behavior
- menu bar behavior

### Step 2. Add required app resources

Required:
- App icon set in an asset catalog.
- Real app target `Info.plist` values.

Carry forward:
- `LSUIElement = YES` because this is a menu bar utility.
- screen recording usage description from the current script-built plist.

Check:
- icon renders correctly in the menu bar app bundle and archive
- bundle identifier matches release plan

### Step 3. Add entitlements and sandbox

This is required for Mac App Store distribution.

Add an entitlements file with at least:
- `com.apple.security.app-sandbox = true`
- `com.apple.security.network.client = true`

Then validate:
- backend network calls still work under sandbox
- screen capture flow still works
- global hotkey still works

Important:
- do not guess extra entitlements unless they are needed
- add the smallest set first, then test

### Step 4. Add privacy manifest

Add `PrivacyInfo.xcprivacy` to the app target.

At minimum, audit:
- ScreenCaptureKit usage
- network access
- any required-reason APIs

Do not leave this to the end. App Store upload review is stricter now.

### Step 5. Move release backend config into build settings

Implement:
- release endpoint in `Info.plist` or xcconfig
- app reads release endpoint from bundle config
- debug override stays debug-only

Validate:
- debug builds still point locally when desired
- release builds never expose URL or token editing
- release builds still translate correctly

### Step 6. Build the archive path

Once the app target is stable:
- create a signed archive
- install it locally
- validate runtime behavior from the archived app, not only from Xcode Run

This matters because:
- screen recording permissions are tied to app identity
- menu bar utilities often behave differently between local debug runs and archived apps

## Backend Release Work

### Required backend changes

Before App Store release:
- remove fail-open auth behavior
- stop relying on a static shared secret embedded in the app
- add rate limiting
- add quotas or abuse controls
- decide how app identity is verified

Recommended backend follow-up:
- keep Google Translation on Cloud Run
- keep EU endpoint and NMT model
- keep chunking near 5K code points
- add auth enforcement and request limits before public release

### Cloud Run review checklist

Check these on the server side:
- `GOOGLE_CLOUD_PROJECT` is correct
- endpoint remains `translate-eu.googleapis.com`
- location remains EU
- model remains `general/nmt`
- logging avoids raw OCR text where possible
- request size limits are enforced

Files to inspect:
- [backend/src/config.js](/Users/ydh0rs/Desktop/Personal/circle2search/backend/src/config.js)
- [backend/src/server.js](/Users/ydh0rs/Desktop/Personal/circle2search/backend/src/server.js)
- [script/deploy_cloud_run.sh](/Users/ydh0rs/Desktop/Personal/circle2search/script/deploy_cloud_run.sh)

## Test Plan On The Xcode Machine

### A. Debug build tests

Verify:
- settings opens correctly
- debug translation service section is visible in debug builds
- debug backend URL persists across relaunch
- debug bearer token persists in Keychain
- translation works against local backend
- translation works against deployed backend

### B. Release build tests

Verify:
- debug translation section is hidden
- no backend URL editing is possible
- no bearer token editing is possible
- release build resolves the fixed production endpoint
- translation still works in release configuration

### C. Permission and identity tests

Verify:
- first-run screen recording prompt appears correctly
- granting permission and relaunching is enough for capture to work
- archived build uses stable permission identity
- rebuilding the archive does not create confusing duplicate permission states

### D. Core UX tests

Verify:
- menu bar icon trigger works
- global hotkey trigger works
- both entry points run the same capture/translate flow
- menu bar and dock are not translated
- overlay glow is visible enough but not heavy
- translated text renders in place and remains readable
- original/translated toggle works repeatedly

### E. Multi-display tests

Verify:
- the display under the mouse cursor is selected
- Retina and non-Retina displays both align correctly
- the overlay positioning and text replacement remain correct across scale factors

### F. Failure tests

Verify:
- backend offline
- backend timeout
- backend 401
- backend 500
- empty OCR result
- no network

Expected:
- clear in-app error messaging
- no stuck overlay session
- graceful return path for the user

### G. Sandbox tests

After enabling App Sandbox:
- screen capture still works
- translation network calls still work
- menu bar utility still launches correctly
- settings window still opens
- global hotkey still works

### H. Archive/TestFlight tests

Verify from the archived app or TestFlight build:
- app launches from Finder / Applications
- settings still open
- translation still works
- permissions still work
- no release-only crashes

Do not rely only on Xcode Run for final validation.

## What Can Stay As-Is

These are not urgent blockers:
- SwiftUI/AppKit structure
- current menu bar app shape
- current settings layout
- current local OCR strategy
- current Google NMT request shape
- current chunking model for synchronous translation

## What Is Nice To Have But Not Required For First Release

- automated backend tests
- automated client-side decoding tests
- further glow polish
- more language options
- more refined overlay typography heuristics

## Practical Release Order

1. Commit current repo state.
2. Move to Xcode machine.
3. Create app target and resources.
4. Add entitlements and privacy manifest.
5. Move release endpoint config out of source.
6. Harden backend auth.
7. Archive locally and test.
8. TestFlight for macOS.
9. App Store Connect privacy + metadata.
10. Release only after the archived build is stable.

## Most Important Remaining Risk

The main remaining shipping risk is backend auth, not UI polish.

If you only fix one thing before packaging, fix that first.
