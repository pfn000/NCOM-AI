from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ResourceBudget:
    """Memory budget in MiB for a constrained local runtime."""

    total_mib: int = 3420
    reserved_os_mib: int = 900
    reserved_runtime_mib: int = 450
    max_model_mib: int = 1500
    max_tool_mib: int = 400

    @property
    def available_mib(self) -> int:
        return max(
            0,
            self.total_mib
            - self.reserved_os_mib
            - self.reserved_runtime_mib
            - self.max_model_mib
            - self.max_tool_mib,
        )


@dataclass
class ResourceGovernor:
    budget: ResourceBudget = ResourceBudget()

    def model_allowed(self, estimated_mib: int) -> bool:
        return 0 < estimated_mib <= self.budget.max_model_mib

    def tool_allowed(self, estimated_mib: int) -> bool:
        return 0 < estimated_mib <= self.budget.max_tool_mib

    def require_model(self, estimated_mib: int) -> None:
        if not self.model_allowed(estimated_mib):
            raise MemoryError(
                f"model budget exceeded: {estimated_mib} MiB > "
                f"{self.budget.max_model_mib} MiB"
            )

    def require_tool(self, estimated_mib: int) -> None:
        if not self.tool_allowed(estimated_mib):
            raise MemoryError(
                f"tool budget exceeded: {estimated_mib} MiB > "
                f"{self.budget.max_tool_mib} MiB"
            )
