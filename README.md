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
- a `ScreenCaptureKit`-backed frozen multi-display selection flow
- local `Vision` OCR for the selected region
- provider/config plumbing for Opper-backed translation
- a project-local `build_and_run.sh` entrypoint

The next implementation slice is:

1. refine the screenshot crop path and overlay polish
2. add translation result presentation near the selected area
3. add Apple Translation as a local provider option
4. add searchable history and shortcut customization

## Run

```bash
./script/build_and_run.sh
```

## Notes

- The default global shortcut is `Control-Shift-Space`.
- Search uses a configurable URL template and requires a `{query}` token.
- Translation is wired for Opper first so users can bring their own key without us operating a proxy service.
