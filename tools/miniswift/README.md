# MiniSwift Visual Verification Tool

NCOM uses MiniSwift Studio as a Swift/SwiftUI visual verification backend.

Reference: https://miniswift.run/studio/

MiniSwift documents the Studio as an in-browser Swift/SwiftUI compiler/runtime with a live canvas and an iPhone-style preview. NCOM treats it as a visual verification oracle, not as a substitute for final Apple toolchain/device validation.

## Purpose

The tool is designed for agents working on SwiftUI to:

1. Send Swift source to MiniSwift Studio.
2. Wait for compilation/render completion.
3. Capture the rendered phone preview with Playwright.
4. Save screenshots and browser diagnostics as test artifacts.
5. Compare successive renders during UI iteration.

## Browser automation

The implementation uses Playwright from Node. It must not bypass authentication, anti-bot controls, or other site security mechanisms.

Example:

```bash
npm install
node miniswift-shot.mjs \
  --source ./ios/NCOMApp/NCOMApp.swift \
  --output ./artifacts/swiftui-preview.png
```

Optional selector overrides:

```bash
node miniswift-shot.mjs \
  --source ./ios/NCOMApp/NCOMApp.swift \
  --output ./artifacts/swiftui-preview.png \
  --editor-selector 'textarea' \
  --run-selector 'button:has-text("Run")' \
  --preview-selector '[data-preview]'
```

## Screenshot contract

The script captures the phone/canvas preview itself, not browser chrome. A caller can supply an explicit preview selector. Without one, the script uses conservative heuristics and fails loudly if it cannot identify a plausible phone preview.

On failure it saves a full-page diagnostic screenshot beside the requested output path.

## Verification policy

A screenshot proves visual rendering in MiniSwift only. It does not prove App Store/device compatibility. NCOM still requires native platform validation before calling iOS support complete.
