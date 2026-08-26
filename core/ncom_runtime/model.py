from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Protocol


class ModelBackend(Protocol):
    def load(self) -> None: ...
    def unload(self) -> None: ...
    def generate(self, messages: Iterable[dict[str, str]], max_tokens: int = 128) -> str: ...


@dataclass
class LlamaCppBackend:
    """Process adapter for a local llama.cpp-compatible runner.

    The runtime intentionally keeps the inference process behind a tiny interface so
    the model engine can be swapped without changing agent/tool code.
    """

    model_path: Path
    executable: str = "llama-cli"
    loaded: bool = False

    def load(self) -> None:
        if not self.model_path.is_file():
            raise FileNotFoundError(self.model_path)
        self.loaded = True

    def unload(self) -> None:
        self.loaded = False

    def generate(self, messages: Iterable[dict[str, str]], max_tokens: int = 128) -> str:
        if not self.loaded:
            raise RuntimeError("model backend is not loaded")
        if max_tokens <= 0:
            raise ValueError("max_tokens must be positive")
        # Deliberately fail closed until the process adapter is implemented. This
        # prevents a fake local model from masquerading as a working inference path.
        raise NotImplementedError("llama.cpp process adapter is the next runtime milestone")
