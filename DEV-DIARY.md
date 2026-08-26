# NCOM AI — DEV Diary

Engineering decisions are recorded here as the project evolves. Entries describe what was actually implemented, what was verified, and what remains unresolved.

## 2026-08-26 — Entry 0007: Native iOS Tool Foundation

### Source material reviewed
- User-supplied UWB/NearbyInteraction, Bonjour, animation, networking, profile/signing, OSINT, tool-registry, and tool-manager Swift examples.
- Prior project architecture and iOS implementation.

### Implemented
- Added `ios/NCOMApp/NCOMNativeTooling.swift` with a real `NCOMNativeTool` protocol and structured `NCOMToolResult`.
- Added real asynchronous DNS resolution, RDAP lookup, and public IP metadata collection using iOS system networking plus public unauthenticated endpoints.
- Added `NCOMToolRegistry` and connected it to `NCOMToolRouter` so native tools have a real execution boundary rather than a static capability label.
- Kept the OSINT implementation limited to public metadata collection; no credentials, tracking bypasses, or private-device access are included.

### Deliberately rejected from direct copy
- Placeholder values such as simulated DNS/IP responses and fake model output.
- Fake debugger register/memory results.
- Code-signature bypass / private-framework installation claims.
- Hypothetical iOS 27 APIs presented as if they were official APIs.
- Blocking semaphore-based networking where structured async APIs are available.

### Next native tool work
- Prompt Lab / Pliny-style local evaluation engine.
- SwiftSyntax-based local code review engine modeled after common CodeRabbit review capabilities.
- Mach-O/file inspection for the debugger-compatible tool.
- Full NCOM MCP adapter and tool-calling bridge for Foundation Models.
- UWB Nearby Interaction pairing with a real accessory/session token exchange.
- Bonjour device protocol, NCOM service authentication, and secure pairing.
- Acoustic receive/decode path (current prototype is transmit-side).
- NCOM Desktop VM integration and artifact export.

### Verification status
- The native OSINT tool has been committed and routed through the Tool Router.
- It has **not yet been declared iOS-build verified**; the next iOS Actions run must compile the new source and run the simulator/UI pipeline before this tool is marked verified.
