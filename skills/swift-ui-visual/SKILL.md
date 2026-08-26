# SwiftUI Visual Verification Skill

## Purpose
Use the MiniSwift Playwright tool when generating or modifying SwiftUI and a visual render check is useful.

## Invocation

```bash
cd tools/miniswift
npm install
node miniswift-shot.mjs --source <swift-file> --output <artifact>.png
```

## Agent behavior

1. Make the smallest SwiftUI change required.
2. Run MiniSwift visual verification.
3. Inspect the resulting phone screenshot.
4. Iterate when layout, spacing, hierarchy, controls, or typography are visibly wrong.
5. Keep the screenshot as evidence for the iteration.
6. Do not call a MiniSwift screenshot a native-device test.

## Failure behavior

If MiniSwift's DOM changes and automatic selectors fail, retry with an explicit selector only when the selector is verified against the current page. Never silently accept a full-browser screenshot as a phone-preview result.
