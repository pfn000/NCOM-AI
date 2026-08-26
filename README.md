# NCOM-AI

NCOM-AI is a local-first AI computing environment and agent platform built for constrained CPUs and designed to scale from a Linux desktop to a browser and native iOS.

## 🚀 One-click iOS build & simulator test

### [▶️ BUILD & RUN NCOM-AI iOS](https://github.com/pfn000/NCOM-AI/actions/workflows/ios.yml)

Click that button, then choose **Run workflow**.

GitHub's macOS runner will:

1. Download the NCOM-AI repository.
2. Generate the iOS Xcode project.
3. Build the native SwiftUI app.
4. Boot an iPhone Simulator.
5. Install the app.
6. Run the UI tests.
7. Capture the simulator screenshot.
8. Upload the `.app` and screenshot as downloadable workflow artifacts.

**Important:** GitHub is providing the macOS/Xcode build machine and iOS Simulator. It is not pretending to be a physical iPhone.

## iOS architecture

The native iOS client is being built as a standalone NCOM application, not as a mandatory localhost shell.

```text
Apple Foundation Models
        │
        ▼
    NCOM Engine
        │
        ▼
  NCOM Tool Router
   ├── MCP
   ├── Skills
   ├── Memory
   ├── Files
   ├── VM boundary
   └── Artifacts
```

Apple Foundation Models is the **cognitive header** when available on the device. NCOM Engine owns execution and system boundaries. The Tool Router gives the model controlled access to in-app capabilities.

The optional desktop runtime is an **expansion layer** for heavier compute, VM display, desktop activity, and other capabilities that iOS cannot provide directly.

### Bundle identity

The intended iOS bundle identifier is:

`com.ncom.ai`

It must be registered and available in the Apple developer account used for a signed device/App Store build.

### After the workflow finishes

Open the completed workflow run and look under **Artifacts** for:

- `NCOMAI-iOS-app` — built iOS Simulator `.app` bundle.
- `NCOMAI-iOS-screenshot` — the actual Simulator screenshot.

## What exists now

- Python runtime core with explicit lifecycle, memory governance, deterministic tool registry, and GGUF/llama.cpp backend contract.
- Automated pytest validation in GitHub Actions.
- Native desktop client source using Python/Tk for a lightweight control surface.
- Browser client source with a real HTTP client for a local NCOM endpoint.
- Native SwiftUI iOS client with Apple Foundation Models integration and an in-app NCOM Engine/Tool Router architecture.
- NCOM iOS About/owner profile surfaces containing the project's supplied identity/provenance metadata.
- Live desktop/VM activity UI that can display a real remote screenshot when the desktop runtime exposes `/v1/activity` and `/v1/display/screenshot`; it does not fabricate a desktop feed.
- GitHub Actions iOS build, simulator test, screenshot, and `.app` artifact pipeline.
- GitHub Actions release pipeline that builds named platform artifacts rather than only one opaque source archive.
- GitHub Pages site with a direct build trigger link and release/download links.

## Hardware target

Primary target: Surface Pro 7, Intel Core i3-1005G1, 3.42 GiB RAM, Intel Iris Plus, CachyOS/Wayland.

The product uses lazy-loaded models and bounded memory budgets. Large models are not silently assumed to fit.

## Local inference

The desktop runtime is designed around a local GGUF model runner. Set `NCOM_MODEL` to a GGUF file and configure a local llama.cpp-compatible executable when using the model backend. No cloud model is required by the core runtime.

The iOS client can use Apple's on-device Foundation Models when supported by the device and OS. When Apple Foundation Models are unavailable, the app reports that state rather than pretending inference succeeded.

## Clients

### Linux / desktop

`desktop/ncom_desktop.py` is a lightweight real desktop control app.

### Web

`web/` is a real static client. It can be served locally or deployed with GitHub Pages. The Build button links directly to the authenticated GitHub Actions workflow-dispatch page; it never embeds a token in public JavaScript.

### iOS

`ios/NCOMApp/` is a native SwiftUI client. It can operate around the local on-device NCOM architecture and can optionally connect to a desktop runtime for heavier capabilities.

## Releases and updates

GitHub Releases are the source artifact channel for development builds. The iOS App Store/TestFlight distribution path remains the Apple-controlled path for signed device builds and end-user updates.

The app must not attempt to bypass Apple's code-signing or provisioning system. For personal-device development, use Xcode Personal Team provisioning. For longer-lived beta/device distribution, use the Apple Developer Program with registered devices, or TestFlight/App Store distribution through App Store Connect.

See `ios/Signing/README.md` for the supported signing and distribution paths.

## Release artifacts

Releases are intended to contain named, usable files rather than one opaque archive:

- `ncom-ai-linux-x86_64` — Linux executable.
- `ncom-ai-web.tar.gz` — deployed web application payload.
- `NCOM-AI-iOS.tar.gz` — iOS Xcode/SwiftUI source bundle.
- `ncom-ai-source-<sha>.tar.gz` — reproducible source snapshot.

## Development

```bash
cd core
python -m pytest -q
```

## Project integrity rule

A directory, button, workflow, or configuration file is not considered a completed feature by itself. Capabilities become complete only when an executable test or a working end-to-end path demonstrates them.

## Engineering log

See `DEV-DIARY.md` for decisions, tests actually run, resource measurements, and unresolved risks.
