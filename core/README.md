# NCOM Agent Core

The core runtime will own model lifecycle, planning/reasoning, memory, permissions, resource governance, and tool routing.

## First implementation milestone

- Define a small runtime state machine.
- Add a resource governor for the 3.42 GiB Surface target.
- Add a model backend interface with a GGUF/llama.cpp implementation.
- Add deterministic tool dispatch before adding autonomous behavior.
- Add executable tests before declaring any capability complete.

Nothing in this directory is considered implemented merely because an interface or UI exists.
