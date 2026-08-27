# NCOM-AI Engineering Contract

## Non-negotiable build rule
Do not describe a feature as implemented because a screen, type, stub, placeholder, fake response, or mock backend exists. A feature is implemented only when its production path compiles, executes, and is tested at the level appropriate to its behavior.

## Review every changed line
Review every human-written changed line for correctness, design, concurrency, security, error handling, state management, accessibility, performance, and maintainability. Do not assume surrounding code is correct.

## No vibe coding
Do not invent framework APIs. Verify APIs against current official documentation and the project's deployment target before coding. Do not silently substitute simulations for requested functionality. Clearly label unsupported platform capabilities and provide a real fallback architecture when possible.

## iOS
NCOM targets iOS 17+ unless the project explicitly changes this. Prefer current Apple SDK APIs. Do not introduce deprecated APIs merely to silence a compiler error. Swift 6 concurrency must be correct rather than disabled globally.

## UI
Reject dashboard-like filler, arbitrary gradients, excessive cards, fake metrics, nonfunctional controls, dead navigation, placeholder interaction, and visually dense layouts without hierarchy. Every interactive control must have a real action and state model.

## Testing
A change should have appropriate unit, integration, UI, and end-to-end validation. Tests must be capable of failing when the implementation is broken; do not add assertion-free smoke tests just to turn CI green.

## NCOM architecture
Keep normal Chat, NCOM Engine, Tool Router, Models, MCP, Skills, VM, Devices, and Apps as one coherent system with explicit boundaries. Do not create duplicate singletons or parallel fake engines for features that already have a canonical subsystem.

## Security
Do not add code-signing bypasses, private-framework installation tricks, credential theft, covert surveillance, or unauthorized device-control behavior. Use documented/public APIs and explicit authorization boundaries.
