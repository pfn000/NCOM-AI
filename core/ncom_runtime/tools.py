from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable


Handler = Callable[[dict[str, Any]], Any]


@dataclass(frozen=True)
class ToolSpec:
    name: str
    description: str
    input_schema: dict[str, Any]
    estimated_mib: int = 32


@dataclass(frozen=True)
class ToolResult:
    ok: bool
    tool: str
    output: Any = None
    error: str | None = None


@dataclass
class ToolRegistry:
    _handlers: dict[str, Handler] = field(default_factory=dict)
    _specs: dict[str, ToolSpec] = field(default_factory=dict)

    def register(self, spec: ToolSpec, handler: Handler) -> None:
        if not spec.name or spec.name in self._handlers:
            raise ValueError(f"tool already registered or unnamed: {spec.name!r}")
        self._specs[spec.name] = spec
        self._handlers[spec.name] = handler

    def describe(self) -> list[ToolSpec]:
        return sorted(self._specs.values(), key=lambda spec: spec.name)

    def invoke(self, name: str, arguments: dict[str, Any]) -> ToolResult:
        handler = self._handlers.get(name)
        if handler is None:
            return ToolResult(False, name, error="unknown tool")
        try:
            return ToolResult(True, name, output=handler(arguments))
        except Exception as exc:  # tools must not crash the agent process
            return ToolResult(False, name, error=f"{type(exc).__name__}: {exc}")
