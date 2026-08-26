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

### Next action
Implement the real llama.cpp process adapter, add an NCOM model configuration/profile, and expose the first executable MCP transport through the local server.

## Entry format
Each future entry should record:
- date
- decision or change
- implementation status
- tests actually run
- resource impact on the Surface target
- unresolved risks
- next action
