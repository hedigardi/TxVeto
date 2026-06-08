"""Command-line demo for TxVeto behavior."""

from __future__ import annotations

import argparse

from .errors import BudgetExceededError, LoopDetectedError
from .guard import VetoGuard


def _simulate_agent(guard: VetoGuard, inject_loop: bool) -> None:
    with guard:
        for i in range(1, 20):
            tool_name = "fetch_web_data" if inject_loop else f"action_{i}"
            guard.inspect_step(
                model="claude-3-5-sonnet",
                input_tokens=50_000,
                output_tokens=2_000,
                tool_name=tool_name,
            )
            print(f"Agent executed tool: {tool_name}")


def run_demo(mode: str) -> None:
    if mode in {"budget", "both"}:
        print("\n=== Budget protection demo ===")
        guard = VetoGuard(max_usd=0.50, max_steps=10)
        try:
            _simulate_agent(guard, inject_loop=False)
        except BudgetExceededError as exc:
            print(f"Budget veto triggered: {exc}")

    if mode in {"loop", "both"}:
        print("\n=== Loop protection demo ===")
        guard = VetoGuard(max_usd=100.00, max_steps=15, loop_threshold=3)
        try:
            _simulate_agent(guard, inject_loop=True)
        except LoopDetectedError as exc:
            print(f"Loop veto triggered: {exc}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the TxVeto demo.")
    parser.add_argument(
        "--mode",
        choices=("budget", "loop", "both"),
        default="both",
        help="Which scenario to demonstrate.",
    )
    args = parser.parse_args()
    run_demo(args.mode)


if __name__ == "__main__":
    main()
