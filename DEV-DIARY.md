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

### Next engineering milestone
Implement the minimal executable runtime skeleton: process lifecycle, configuration, resource governor, model backend interface, MCP registry, and test harness. Then add the first real local model and a functional UI around it.

## 2026-08-26 — Entry 0002: Runtime 0.1 Skeleton

### Implemented
- Added `core/ncom_runtime/state.py` with an explicit runtime state machine.
- Added `core/ncom_runtime/governor.py` with a conservative Surface-oriented memory budget.
- Added `core/ncom_runtime/tools.py` with deterministic tool registration/invocation and exception containment.
- Added `core/ncom_runtime/model.py` with a GGUF/llama.cpp backend contract and fail-closed loading behavior.
- Added `core/tests/test_runtime.py` covering state transitions, resource policy, and tool error isolation.
- Updated GitHub Actions CI to install Python and execute the pytest suite.

### Tests actually run
- Local pytest execution against the runtime skeleton: **4 passed in 0.06s**.
- The local shell could not resolve `github.com`, so a git clone from the execution environment was unavailable.
- CodeRabbit CLI was not runnable in this environment because the required CLI/authentication path is not available here. No CodeRabbit result is being claimed.

### Important implementation note
The model backend intentionally raises `NotImplementedError` during generation until the real llama.cpp process adapter is added. This prevents a placeholder response generator from being mistaken for a functioning local AI.

### Resource impact
The skeleton has no persistent model process and adds only standard-library Python code to the runtime path. This is intentionally low-resident-memory work suitable for the 3.42 GiB target.

### Next action
Add the real local GGUF process adapter, model discovery/configuration, bounded context handling, and the first executable MCP transport.

## Entry format
Each future entry should record:
- date
- decision or change
- implementation status
- tests actually run
- resource impact on the Surface target
- unresolved risks
- next action
