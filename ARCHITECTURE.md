# NCOM AI Architecture

## Mission
NCOM AI is a local-first, CPU-first agent platform designed to operate on constrained Linux hardware while remaining portable to browser and iOS clients.

## Runtime layers
1. Agent kernel — planning, reasoning loop, model routing, memory, permissions.
2. Local inference — GGUF/llama.cpp-compatible CPU backend.
3. MCP bus — typed discovery, invocation, lifecycle, permissions, resource cost.
4. Skills — signed/versioned capability packs loaded on demand.
5. Integrations — SpiderFoot, debugger compatibility layer, local code review, filesystem, shell, browser, GitHub, and VM applications.
6. VM layer — QEMU orchestration with KolibriOS and application VMs.
7. Clients — native Linux desktop, browser/PWA, and iOS shell.

## Resource model
The primary target is a Surface Pro 7 with Intel Core i3-1005G1, 3.42 GiB RAM, Intel Iris Plus integrated graphics, and limited free storage. RAM-heavy services therefore use lazy loading, bounded context, explicit lifecycle state, and an idle-unload policy.

## Debugger compatibility
NCOM implements a clean-room debugger capability layer at the MCP/tool boundary. It is intended to provide comparable workflows to x64dbg-MCP without requiring the Windows x64dbg binary on Linux.

## Code review
NCOM includes a local code-review engine. CodeRabbit is supported as an optional external review provider when configured; the product must remain functional without that service.

## VM applications
SaaSTools.site and findly.tools are treated as application payloads/integration targets for the internal VM layer. Their network behavior, licensing, and availability must be verified before packaging any third-party component.

## Completion rule
A subsystem is only marked complete after executable tests demonstrate that its advertised behavior works. Documentation, placeholders, and UI mock-ups never count as implementation.
