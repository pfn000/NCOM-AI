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

## Entry format
Each future entry should record:
- date
- decision or change
- implementation status
- tests actually run
- resource impact on the Surface target
- unresolved risks
- next action
