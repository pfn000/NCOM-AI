from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class RuntimeState(str, Enum):
    STOPPED = "stopped"
    STARTING = "starting"
    READY = "ready"
    BUSY = "busy"
    DEGRADED = "degraded"
    STOPPING = "stopping"
    ERROR = "error"


_ALLOWED: dict[RuntimeState, set[RuntimeState]] = {
    RuntimeState.STOPPED: {RuntimeState.STARTING},
    RuntimeState.STARTING: {RuntimeState.READY, RuntimeState.ERROR},
    RuntimeState.READY: {RuntimeState.BUSY, RuntimeState.DEGRADED, RuntimeState.STOPPING},
    RuntimeState.BUSY: {RuntimeState.READY, RuntimeState.DEGRADED, RuntimeState.ERROR},
    RuntimeState.DEGRADED: {RuntimeState.READY, RuntimeState.BUSY, RuntimeState.STOPPING, RuntimeState.ERROR},
    RuntimeState.STOPPING: {RuntimeState.STOPPED, RuntimeState.ERROR},
    RuntimeState.ERROR: {RuntimeState.STARTING, RuntimeState.STOPPING, RuntimeState.STOPPED},
}


@dataclass
class RuntimeStateMachine:
    state: RuntimeState = RuntimeState.STOPPED

    def transition(self, target: RuntimeState) -> None:
        if target not in _ALLOWED[self.state]:
            raise ValueError(f"invalid runtime transition: {self.state.value} -> {target.value}")
        self.state = target

    def can_transition(self, target: RuntimeState) -> bool:
        return target in _ALLOWED[self.state]
