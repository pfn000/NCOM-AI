---
name: ios-swift-development
description: Build, review, debug, and visually verify native iOS and SwiftUI applications using Apple's official SDK documentation and NCOM's MiniSwift Playwright verification workflow.
---

# iOS + SwiftUI Development

Use this skill whenever the task involves Swift, SwiftUI, iOS application architecture, UI implementation, navigation, state/data flow, Apple platform capabilities, or iOS distribution.

## Source-of-truth policy

Prefer Apple's official Developer Documentation and Xcode documentation for platform behavior and API signatures. Do not invent SwiftUI APIs from memory when an official reference is available.

Primary references:
- SwiftUI overview: https://developer.apple.com/documentation/SwiftUI
- SwiftUI landing page: https://developer.apple.com/swiftui/
- SwiftUI Pathway: https://developer.apple.com/swiftui/get-started/
- Xcode documentation: https://developer.apple.com/documentation/Xcode
- Creating an Xcode project: https://developer.apple.com/documentation/xcode/creating-an-xcode-project-for-an-app/
- SwiftUI `App`: https://developer.apple.com/documentation/swiftui/app
- SwiftUI navigation: https://developer.apple.com/documentation/swiftui/navigation
- NavigationStack: https://developer.apple.com/documentation/swiftui/navigationstack
- SwiftUI model data / Observation: https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app/
- Scrollable and lazy stacks: https://developer.apple.com/documentation/swiftui/creating-performant-scrollable-stacks
- App capabilities: https://developer.apple.com/documentation/xcode/adding-capabilities-to-your-app/
- App distribution: https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution
- App Store Connect API: https://developer.apple.com/documentation/appstoreconnectapi

## Current-platform awareness

Check Apple's SwiftUI update notes for the current Xcode/SDK generation before using newly introduced APIs. For the 2026 platform generation, Apple documents changes associated with Xcode 27 and later, including updates to `@State`, content builders, reorderable containers, and swipe-action APIs.

## Architecture rules

- Prefer the SwiftUI `App` lifecycle for a SwiftUI application.
- Model navigation explicitly with `NavigationStack`, `NavigationPath`, `TabView`, or platform-appropriate navigation containers.
- For iOS 17+ targets, prefer SwiftUI Observation (`@Observable`) where appropriate and avoid reflexively using `ObservableObject`/`StateObject` for new code.
- Start with standard `VStack`/`HStack`/`ZStack`; use `LazyVStack`/`LazyHStack` when profiling or scale warrants it.
- Keep platform-specific functionality behind clear adapters so the core NCOM client remains testable.
- Use Apple's Human Interface Guidelines for interaction and accessibility decisions.

## Verification workflow

1. Compile/check Swift syntax and project structure with the available native toolchain.
2. For SwiftUI visual changes, use `tools/miniswift/miniswift-shot.mjs` against MiniSwift Studio.
3. MiniSwift is a visual verification oracle, not the final Apple SDK/device build.
4. Wait for an explicit successful build status before capturing the preview.
5. Capture only the phone preview, not browser chrome.
6. Capture console/diagnostic output on failure.
7. For release readiness, validate through Xcode on macOS and/or an actual simulator/device because MiniSwift does not substitute for Apple's native toolchain.

## Anthropic skill pattern

Anthropic's public Agent Skills repository demonstrates the `SKILL.md` format and a `webapp-testing` skill that uses Playwright, waits for dynamic pages to settle, performs DOM reconnaissance, captures screenshots, and records console diagnostics. NCOM's Swift visual verifier follows those principles while keeping the MiniSwift-specific implementation local to NCOM.

Reference: https://github.com/anthropics/skills/tree/main/skills/webapp-testing
