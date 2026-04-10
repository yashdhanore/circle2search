# CircleToSearch

`CircleToSearch` is a macOS menu bar utility for Circle-to-Search style workflows:

- trigger a global shortcut
- select an area on screen
- OCR text locally
- search that text
- translate that text through a user-configured provider

## Current Milestone

This scaffold includes:

- a SwiftPM macOS app target
- a `MenuBarExtra` app shell
- a settings window
- a Carbon-backed global hotkey
- a multi-display AppKit overlay coordinator
- provider/config plumbing for local OCR plus Opper-backed translation
- a project-local `build_and_run.sh` entrypoint

The next implementation slice is:

1. freeze the screen with `ScreenCaptureKit`
2. crop the selected region
3. run `Vision` OCR on the crop
4. connect the OCR result to the existing search and translation actions

## Run

```bash
./script/build_and_run.sh
```

## Notes

- The default global shortcut is `Control-Shift-Space`.
- Search uses a configurable URL template and requires a `{query}` token.
- Translation is wired for Opper first so users can bring their own key without us operating a proxy service.
