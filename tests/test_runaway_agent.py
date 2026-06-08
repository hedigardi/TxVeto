import os
import sys

import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from txveto.errors import BudgetExceededError, LoopDetectedError
from txveto.guard import VetoGuard


def simulate_runaway_agent(guard: VetoGuard, inject_loop: bool = False):
    """Simulate an agent that keeps making expensive calls."""

    print("\n--- Starting AI agent execution ---")

    with guard:
        for i in range(1, 20):
            model = "claude-3-5-sonnet"
            input_tokens = 50_000
            output_tokens = 2_000
            tool = "fetch_web_data" if inject_loop else f"action_{i}"

            guard.inspect_step(
                model=model,
                input_tokens=input_tokens,
                output_tokens=output_tokens,
                tool_name=tool,
            )

            print(f"Agent executing tool: {tool}...")


def test_prevent_wallet_drain():
    guard = VetoGuard(max_usd=0.50, max_steps=10)

    with pytest.raises(BudgetExceededError) as exc_info:
        simulate_runaway_agent(guard, inject_loop=False)

    print(f"\nTxVeto saved us! Error message: {exc_info.value}")


def test_prevent_infinite_tool_loop():
    guard = VetoGuard(max_usd=100.00, max_steps=15, loop_threshold=3)

    with pytest.raises(LoopDetectedError) as exc_info:
        simulate_runaway_agent(guard, inject_loop=True)

    print(f"\nTxVeto stopped the loop! Error message: {exc_info.value}")
