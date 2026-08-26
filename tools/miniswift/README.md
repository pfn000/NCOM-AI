# MiniSwift Visual Verification Tool

NCOM uses MiniSwift Studio as a Swift/SwiftUI visual verification backend.

Reference: https://miniswift.run/studio/

## Purpose

This tool is designed for agents working on SwiftUI to:

1. Send Swift source to MiniSwift Studio.
2. Wait for compilation/render completion.
3. Capture the rendered phone preview with Playwright.
4. Save screenshots and console/DOM diagnostics as test artifacts.
5. Compare successive renders during UI iteration.

MiniSwift's public documentation says its Studio runs compilation/runtime work in the browser and provides a live SwiftUI canvas; its support matrix documents the currently rendered SwiftUI surface. This makes it useful as a visual-feedback oracle, not as a replacement for Apple's final Xcode/device build. citeturn748886search2turn748886search5

## Browser automation

The implementation intentionally uses Playwright from a Node environment. A browser automation session must not bypass authentication, anti-bot controls, or site security mechanisms.

Expected command shape:

```bash
node tools/miniswift/miniswift-shot.mjs \
  --source ./ios/NCOMApp/NCOMApp.swift \
  --output ./artifacts/swiftui-preview.png
```

## Screenshot contract

The script should capture the phone/canvas preview itself, not the entire browser chrome. Prefer a stable semantic selector supplied by the Studio. If the Studio changes its DOM, the script must fail loudly and record a diagnostic screenshot instead of silently capturing the wrong area.

## Verification policy

A screenshot proves visual rendering in MiniSwift only. It does not prove App Store/device compatibility. NCOM still requires native platform validation before calling iOS support complete.
