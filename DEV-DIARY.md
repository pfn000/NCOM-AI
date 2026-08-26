# NCOM AI — DEV Diary

Engineering decisions are recorded here as the project evolves. Entries describe what was actually implemented, what was verified, and what remains unresolved.

## 2026-08-26 — Entry 0001: Architecture Lock

### Hardware constraint
Primary development target: Surface Pro 7 / Intel Core i3-1005G1 / 3.42 GiB RAM / Intel Iris Plus / CachyOS Linux.

### Decisions
- CPU-only local inference is mandatory for the core product.
- GGUF-compatible inference is the initial model path.
- Models, embeddings, tools, and VMs are lazy-loaded rather than resident simultaneously.
- The application must be a real Linux program; mock UI and simulated backend behavior are prohibited.
- MCP and Skills are first-class runtime capabilities.
- GitHub is the canonical source/control plane.
- GitHub Actions builds and tests artifacts; Releases/Packages distribute bundles.
- A local `ncom-sync` workspace abstraction will provide versioned remote-workspace behavior rather than pretending GitHub is a block filesystem.
- x64dbg-MCP functionality is approached as a clean-room compatibility target implemented through a Linux-native debugger backend.
- CodeRabbit is supported as an optional external reviewer; NCOM's local review engine must remain useful without it.
- SpiderFoot and Pliny/L1B3RT4S are integration/skill targets.
- QEMU provides the internal VM layer, including KolibriOS and separately managed application payloads.

### Explicit non-claims
At this point no subsystem is declared production-complete merely because its directory or configuration exists. Third-party services and application payloads require interface/licensing verification before packaging.

## 2026-08-26 — Entry 0002: Runtime 0.1 Skeleton

### Implemented
- Added runtime state machine, resource governor, tool registry, and GGUF backend contract.
- Added pytest coverage and CI execution.

### Tests actually run
- Local pytest execution against the runtime skeleton: **4 passed in 0.06s**.
- The local shell could not resolve `github.com`, so a git clone from the execution environment was unavailable.
- CodeRabbit CLI was not runnable in this environment because the required CLI/authentication path is not available here. No CodeRabbit result is being claimed.

### Important implementation note
The model backend intentionally raises `NotImplementedError` during generation until the real llama.cpp process adapter is added. This prevents a fake local model from masquerading as working inference.

## 2026-08-26 — Entry 0003: Product Surface Upgrade

### Implemented
- Replaced the placeholder README with a real project guide and run instructions.
- Added `desktop/ncom_desktop.py`, a functional lightweight GUI that performs health requests and chat requests against a local NCOM endpoint.
- Added `core/ncom_server.py`, a real HTTP service with `/health` and `/v1/chat` endpoints and explicit fail-closed behavior when no GGUF model is configured.
- Added a real web client in `web/` with endpoint configuration, health checks, chat requests, GitHub Actions build trigger link, Releases link, and repository link.
- Added a native SwiftUI iOS client source tree in `ios/NCOMApp/` that communicates with an NCOM runtime over HTTP/LAN.
- Reworked the release workflow to publish named Release assets: Linux executable, web bundle, iOS source bundle, and source snapshot.
- Reworked GitHub Pages deployment to serve the actual web client instead of markdown copies.
- Expanded CI to compile the desktop/server Python code and validate the actual web/iOS source files.

### Tests actually run
- Repository-side CI has been updated to run the new validation automatically on every push and pull request.
- Release workflow is configured but a GitHub Release is only created when the workflow is manually dispatched with a version or a matching version tag is pushed. This environment cannot dispatch a new Actions run or create a Release directly through the available GitHub connector.
- No claim is made that a Release has already been published.

### Resource impact
The desktop client and HTTP server use Python standard library components. The web client is static. The iOS client is native SwiftUI source. These additions do not reserve model memory on the Surface.

## 2026-08-26 — Entry 0004: MiniSwift SwiftUI Visual Verification

### Implemented
- Added `tools/miniswift/README.md` documenting the MiniSwift visual-verification contract.
- Added `tools/miniswift/package.json` with Playwright as the browser automation dependency.
- Added `tools/miniswift/miniswift-shot.mjs`, an executable browser driver that loads MiniSwift Studio, enters Swift source, triggers Run/Compile, identifies the phone preview, and captures the preview as PNG.
- Added `skills/swift-ui-visual/SKILL.md` so the NCOM agent can invoke visual verification while working on SwiftUI.
- Added `mcp/tools/miniswift.json` registering the visual verifier as an agent-accessible MCP-style tool definition.
- Added loud failure diagnostics: if the preview cannot be identified, the tool writes a full-page diagnostic screenshot instead of silently accepting a browser screenshot.

### Verification basis
MiniSwift's public site documents the Studio as a browser-resident Swift/SwiftUI compiler/runtime with a live iPhone-style canvas. The public support page also documents the SwiftUI API coverage used by the Studio.

### 2026-08-26 — Follow-up: asynchronous build handling
- User-provided Studio console output showed repeated `KUI2031` platform-extension warnings followed by `Build succeeded · 3 view(s)`.
- Determined that the original screenshot driver searched for the phone preview immediately after pressing Run, before asynchronous compilation/render completion.
- Updated `miniswift-shot.mjs` to wait for the explicit `Build succeeded · N view(s)` message before attempting preview detection.
- Added an optional `--success-selector` override for future MiniSwift DOM changes.
- Kept `KUI2031` warnings non-fatal; the explicit build-success signal is the authoritative compilation result for this automation step.

### Tests actually run
- The repository contains the updated Playwright adapter and selector fallbacks.
- The local environment still does not have the Playwright Node package installed, so an actual browser screenshot has not been claimed from this environment.
- The provided MiniSwift log demonstrates a successful build (`Build succeeded · 3 view(s)`); it does not demonstrate screenshot capture.

### Next action
Install Playwright in the target development environment, run the first real SwiftUI screenshot against MiniSwift Studio, inspect the captured phone image, and add the resulting screenshot smoke test to CI.

## Entry format
Each future entry should record:
- date
- decision or change
- implementation status
- tests actually run
- resource impact on the Surface target
- unresolved risks
- next action
