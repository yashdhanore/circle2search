# Xcode Machine Checklist

This repo is developed from a machine without usable Xcode access. Use this checklist on the other machine whenever Xcode-specific validation is needed.

## Open Source Scheme

Use this for the developer/self-hosted path.

1. Open `CircleToSearch.xcodeproj`
2. Select `CircleToSearch Open Source`
3. Build and run
4. Paste a Google Translate API key in Settings
5. Confirm the local backend starts and translation works

If you want the open-source build to run without Node at runtime:

```bash
./script/build_local_backend_helper.sh
```

Then rebuild the scheme and verify the packaged-helper path still works.

Validate:
- `Run On This Mac` is visible
- the Google API key is stored in Keychain
- local backend status becomes healthy
- translation works against `127.0.0.1`
- the `Advanced` section still works for remote backends

## Managed Scheme

Use this for the managed-backend / release path.

1. Select `CircleToSearch`
2. Build Debug and Release
3. Confirm release builds do not expose self-host configuration
4. Confirm the managed backend URL resolves from xcconfig / plist

Validate:
- debug build can still use the managed backend flow
- release build hides backend URL/token editing
- release build uses the fixed managed endpoint

## Archive / Release Validation

Use this only when working on the App Store path.

Validate:
- archive succeeds
- sandboxed build still captures the screen
- network client entitlement is sufficient for translation calls
- settings window still opens
- hotkey still works
- receipt-backed auth works in the archived build

Relevant files:
- `Resources/CircleToSearch.entitlements`
- `Resources/CircleToSearchOpenSource.entitlements`
- `Resources/PrivacyInfo.xcprivacy`
- `Config/Debug.xcconfig`
- `Config/Release.xcconfig`
- `Config/OpenSource.xcconfig`

## Current Machine Constraint

Keep this assumption in mind for future work:

- this machine can edit code and run repo-local checks
- this machine cannot be trusted for Xcode build, archive, signing, or TestFlight validation
- all Xcode-specific verification must happen on the other machine
