import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

from ncom_runtime.governor import ResourceBudget, ResourceGovernor
from ncom_runtime.state import RuntimeState, RuntimeStateMachine
from ncom_runtime.tools import ToolRegistry, ToolSpec


def test_state_machine_happy_path() -> None:
    machine = RuntimeStateMachine()
    machine.transition(RuntimeState.STARTING)
    machine.transition(RuntimeState.READY)
    machine.transition(RuntimeState.BUSY)
    machine.transition(RuntimeState.READY)
    assert machine.state is RuntimeState.READY


def test_state_machine_rejects_invalid_transition() -> None:
    machine = RuntimeStateMachine()
    try:
        machine.transition(RuntimeState.BUSY)
    except ValueError as exc:
        assert "invalid runtime transition" in str(exc)
    else:
        raise AssertionError("invalid transition was accepted")


def test_resource_governor() -> None:
    governor = ResourceGovernor(ResourceBudget(max_model_mib=1500))
    assert governor.model_allowed(512)
    assert not governor.model_allowed(1600)


def test_tool_registry_returns_result_and_isolates_errors() -> None:
    registry = ToolRegistry()
    registry.register(
        ToolSpec("echo", "echo input", {"type": "object"}),
        lambda args: args["value"],
    )
    registry.register(
        ToolSpec("explode", "test error containment", {"type": "object"}),
        lambda _: 1 / 0,
    )

    assert registry.invoke("echo", {"value": "hello"}).output == "hello"
    failed = registry.invoke("explode", {})
    assert not failed.ok
    assert failed.error is not None
    assert registry.invoke("missing", {}).ok is False
