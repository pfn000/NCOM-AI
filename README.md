# NCOM-AI

NCOM-AI is a local-first agent platform built for constrained CPUs and designed to scale from a Linux desktop to a browser and iOS client.

## 🚀 One-click iOS build & simulator test

### [▶️ BUILD & RUN NCOM-AI iOS](https://github.com/pfn000/NCOM-AI/actions/workflows/ios.yml)

Click that button, then choose **Run workflow**.

GitHub's macOS runner will:

1. Download the NCOM-AI repository.
2. Generate/open the iOS Xcode project.
3. Build the native SwiftUI app.
4. Boot an iPhone Simulator.
5. Install the app.
6. Run the UI tests.
7. Capture the simulator screenshot.
8. Upload the `.app` and screenshot as downloadable workflow artifacts.

**Important:** GitHub is providing the macOS/Xcode build machine and iOS Simulator. It is not pretending to be a physical iPhone. A physical-device build requires Apple signing/provisioning.

### After the workflow finishes

Open the completed workflow run and look under **Artifacts** for:

- `NCOMAI-iOS-app` — built iOS `.app` bundle.
- `NCOMAI-iOS-screenshots` — simulator screenshots and test evidence.

## What exists now

- Python runtime core with explicit lifecycle, memory governance, deterministic tool registry, and GGUF/llama.cpp backend contract.
- Automated pytest validation in GitHub Actions.
- Native desktop client source using Python/Tk for a lightweight Linux/Windows/macOS control surface.
- Browser client source with a real HTTP client for a local NCOM endpoint.
- SwiftUI iOS client source for connecting to a NCOM runtime on the same network.
- GitHub Actions release pipeline that builds a real Linux executable, web application bundle, iOS source bundle, and source manifest and publishes them as named Release assets.
- GitHub Pages site with a direct build trigger link and Release/download links.

## Hardware target

Primary target: Surface Pro 7, Intel Core i3-1005G1, 3.42 GiB RAM, Intel Iris Plus, CachyOS/Wayland.

The product uses lazy-loaded models and bounded memory budgets. Large models are not silently assumed to fit.

## Local inference

The runtime is designed around a local GGUF model runner. Set `NCOM_MODEL` to a GGUF file and configure a local llama.cpp-compatible executable when using the model backend. No cloud model is required by the core runtime.

## Clients

### Linux / desktop

`desktop/ncom_desktop.py` is a lightweight real desktop control app. It reads local NCOM configuration, displays runtime state, sends HTTP requests to a local NCOM endpoint, and opens the project/release pages.

### Web

`web/` is a real static client. It can be served locally or deployed with GitHub Pages. The Build button links directly to the authenticated GitHub Actions workflow-dispatch page; it never embeds a token in public JavaScript.

### iOS

`ios/NCOMApp/` is a SwiftUI app source tree. It connects to a user-specified NCOM endpoint such as `http://192.168.x.x:8765` and sends chat requests over the LAN.

## Release artifacts

Releases are intended to contain named, usable files rather than one opaque archive:

- `ncom-ai-linux-x86_64` — PyInstaller-built executable.
- `ncom-ai-web.tar.gz` — deployed web application payload.
- `NCOM-AI-iOS.tar.gz` — iOS Xcode/SwiftUI source bundle.
- `ncom-ai-source-<sha>.tar.gz` — reproducible source snapshot.

Release creation is automated from tags matching `v*.*.*` or can be started from the Actions tab with a version input.

## Development

```bash
cd core
python -m pytest -q

cd ../desktop
python ncom_desktop.py
```

## Project integrity rule

A directory, button, workflow, or configuration file is not considered a completed feature by itself. Capabilities become complete only when an executable test or a working end-to-end path demonstrates them.

## Engineering log

See `DEV-DIARY.md` for decisions, tests actually run, resource measurements, and unresolved risks.
