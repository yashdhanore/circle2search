# CircleToSearch Xcode Handoff

This document is the release and validation handoff for the Xcode-enabled machine.

Current repo state:
- The app is functional as a macOS menu bar utility.
- Local OCR is on-device with Vision.
- Translation goes through the managed Google Cloud Translation backend.
- Debug-only backend URL and bearer token controls exist in Settings.
- A real Xcode project now exists in `CircleToSearch.xcodeproj`.
- The app now has:
  - an app target
  - app icons in `Resources/Assets.xcassets`
  - a target `Info.plist`
  - an entitlements file
  - a privacy manifest
  - debug/release xcconfig files
- The app is still not ready for App Store submission until archive-time validation and backend auth hardening are completed.

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

## What Is Already Correct

These parts are now in good shape and do not need to be redone on the Xcode machine:

- Xcode project exists:
  - `CircleToSearch.xcodeproj`
- App target is wired to the existing source tree.
- App icon asset catalog exists:
  - `Resources/Assets.xcassets`
- Info plist exists and is target-managed:
  - `Resources/CircleToSearch-Info.plist`
- App Sandbox entitlements file exists:
  - `Resources/CircleToSearch.entitlements`
- Privacy manifest exists:
  - `Resources/PrivacyInfo.xcprivacy`
- Debug and release xcconfig files exist:
  - `Config/Debug.xcconfig`
  - `Config/Release.xcconfig`
- Release backend URL is no longer hardcoded purely in Swift source.
  - It is now provided via `ManagedTranslationBaseURL` in the bundle config.

## Must Validate Before App Store Release

### 1. Validate the new closed backend auth model

Current state:
- The backend is now fail-closed.
- Release builds are expected to authenticate with an App Store receipt header.
- Debug builds can authenticate with an explicit bearer token.
- The backend also rate-limits authenticated subjects.

Files:
- [server.js](/Users/ydh0rs/Desktop/Personal/circle2search/backend/src/server.js)
- [appStoreReceiptAuth.js](/Users/ydh0rs/Desktop/Personal/circle2search/backend/src/appStoreReceiptAuth.js)
- [rateLimiter.js](/Users/ydh0rs/Desktop/Personal/circle2search/backend/src/rateLimiter.js)
- [AppRuntimeConfiguration.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Support/AppRuntimeConfiguration.swift)
- [AppStoreReceiptProvider.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/Services/AppStoreReceiptProvider.swift)

Why this still needs testing:
- The release auth path depends on a real App Store or TestFlight receipt being present in the archived app.
- This machine cannot validate that path.
- The backend now checks receipts against Apple production first and retries sandbox when needed, but that must be verified with a real signed build.

What to validate on the Xcode machine:
- release/archive builds send a valid receipt-backed request
- the backend accepts that receipt
- debug builds still work with the explicit debug token
- unauthorized requests return 401
- repeated requests hit the rate limiter only when expected

Pragmatic release note:
- This is much stronger than the old shared-secret-only path.
- For a free public app, you should still monitor cost and abuse patterns after launch.

### 2. Release backend URL must be finalized and validated from bundle config

Current state:
- Release config is now improved.
- The app reads `ManagedTranslationBaseURL` from the bundle configuration.
- That value comes from the Xcode config files.

Why this still needs work:
- The release URL still needs to be validated in a real archive.
- The production hostname must be the real deployed backend.
- You need to confirm the release build actually reads the bundled value correctly.

What needs to change on the Xcode machine:
- Confirm the release value in `Config/Release.xcconfig`.
- Confirm it flows into `Resources/CircleToSearch-Info.plist`.
- Confirm the archived release app resolves that value correctly at runtime.

Recommended shape:
- `DEBUG`:
  - local Cloud Run URL override allowed
  - debug token field visible
- `RELEASE`:
  - fixed production URL from build config
  - no debug override UI
  - no bearer token field in settings

### 3. Real archive and distribution validation are still missing

Current state:
- The repo now has a real Xcode app target.
- The local shell build script still exists for development, but it is no longer the release path.

Why this matters:
- Presence of the Xcode project is not enough.
- Archive-time behavior is what matters for screen recording permissions, signing identity, sandbox behavior, and App Store readiness.

What needs to be created on the Xcode machine:
- A successful archive.
- A locally installed archived app.
- A TestFlight or Organizer validation pass.
- Final signing, provisioning, and App Store Connect validation.

## Xcode Machine Work Plan

### Step 1. Open and validate the Xcode project

Goal:
- Confirm the project opens cleanly and builds with full Xcode.
- Validate that the app target is using the existing repo structure correctly.

Recommended approach:
- Open `CircleToSearch.xcodeproj`.
- Confirm the `CircleToSearch` scheme is shared and selected.
- Build Debug in Xcode.
- Fix any machine-specific signing or toolchain issues there, not in the repo blindly.

What to preserve:
- `@main` app entry in [CircleToSearchApp.swift](/Users/ydh0rs/Desktop/Personal/circle2search/Sources/App/CircleToSearchApp.swift)
- the existing AppKit bridge points
- settings window behavior
- menu bar behavior

### Step 2. Validate required app resources

Required:
- App icon set in the asset catalog.
- Real app target `Info.plist` values.

Carry forward:
- `LSUIElement = YES` because this is a menu bar utility.
- screen recording usage description from the target plist.
- `ManagedTranslationBaseURL` from build config.

Check:
- icon renders correctly in the menu bar app bundle and archive
- bundle identifier matches release plan
- release and debug values resolve correctly

### Step 3. Validate entitlements and sandbox in Xcode

This is now scaffolded in the repo, but must still be validated in an actual build.

Current file:
- `Resources/CircleToSearch.entitlements`

Expected keys:
- `com.apple.security.app-sandbox = true`
- `com.apple.security.network.client = true`

Then validate:
- backend network calls still work under sandbox
- screen capture flow still works
- global hotkey still works

Important:
- do not guess extra entitlements unless they are needed
- add the smallest set first, then test

### Step 4. Validate privacy manifest

Current file:
- `Resources/PrivacyInfo.xcprivacy`

At minimum, audit:
- ScreenCaptureKit usage
- network access
- any required-reason APIs

Current manifest covers:
- `UserDefaults` accessed API reason

Still verify in Xcode/App Store validation:
- no additional required-reason APIs are flagged
- the manifest is actually bundled in the app archive

### Step 5. Validate debug and release configuration behavior

Implement:
- debug endpoint in `Config/Debug.xcconfig`
- release endpoint in `Config/Release.xcconfig`
- app reads `ManagedTranslationBaseURL` from `Info.plist`
- debug override stays debug-only

Validate:
- debug builds still point locally when desired
- release builds never expose URL or token editing
- release builds still translate correctly

### Step 6. Build and validate the archive path

Once the app target is stable:
- create a signed archive
- install it locally
- validate runtime behavior from the archived app, not only from Xcode Run

This matters because:
- screen recording permissions are tied to app identity
- menu bar utilities often behave differently between local debug runs and archived apps

## Backend Release Work

### Required backend changes

Implemented now:
- fail-open auth removal
- App Store receipt auth for release clients
- debug bearer auth for local development
- per-subject in-memory rate limiting

Recommended backend follow-up:
- keep Google Translation on Cloud Run
- keep EU endpoint and NMT model
- keep chunking near 5K code points
- monitor and tune rate limits before public release
- decide whether you need a stronger long-term abuse-control layer than receipt validation alone

### Cloud Run review checklist

Check these on the server side:
- `GOOGLE_CLOUD_PROJECT` is correct
- endpoint remains `translate-eu.googleapis.com`
- location remains EU
- model remains `general/nmt`
- `APP_STORE_EXPECTED_BUNDLE_ID` matches the final shipping bundle ID
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
- missing debug token fails with a clear local auth error

### B. Release build tests

Verify:
- debug translation section is hidden
- no backend URL editing is possible
- no bearer token editing is possible
- release build resolves the fixed production endpoint
- translation still works in release configuration
- release build successfully reads the App Store receipt
- release build sends receipt-backed auth without any user configuration

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
- backend 429 rate limit
- invalid or missing receipt
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
- Xcode project structure
- asset catalog setup
- Info plist / xcconfig / entitlements / privacy manifest scaffold

## What Is Nice To Have But Not Required For First Release

- automated backend tests
- automated client-side decoding tests
- further glow polish
- more language options
- more refined overlay typography heuristics

## Practical Release Order

1. Commit current repo state.
2. Move to Xcode machine.
3. Open the Xcode project and build Debug.
4. Validate debug and release config behavior.
5. Validate entitlements and privacy manifest in a real build.
6. Harden backend auth.
7. Archive locally and test the archived app.
8. TestFlight for macOS.
9. App Store Connect privacy + metadata.
10. Release only after the archived build is stable.

## Most Important Remaining Risk

The main remaining shipping risk is now archive-time validation of the receipt-backed auth path, not the basic app structure.

If you only fix one thing before packaging, validate the archived release build against the production backend.
