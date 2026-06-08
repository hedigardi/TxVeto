"""Local budget and loop guard for AI agent execution."""

from __future__ import annotations

from typing import Dict, List, Optional

from .errors import BudgetExceededError, LoopDetectedError

PRICING: Dict[str, Dict[str, float]] = {
    "gpt-4o": {"in": 2.50 / 1_000_000, "out": 10.00 / 1_000_000},
    "gpt-4o-mini": {"in": 0.150 / 1_000_000, "out": 0.600 / 1_000_000},
    "claude-3-5-sonnet": {"in": 3.00 / 1_000_000, "out": 15.00 / 1_000_000},
}


class VetoGuard:
    def __init__(self, max_usd: float, max_steps: int = 15, loop_threshold: int = 3):
        self.max_usd = max_usd
        self.max_steps = max_steps
        self.loop_threshold = loop_threshold
        self.spent_usd = 0.0
        self.steps = 0
        self.tool_calls: List[str] = []
        self.is_active = False

    def __enter__(self) -> "VetoGuard":
        self.is_active = True
        return self

    def __exit__(self, exc_type, exc_val, exc_tb) -> None:
        self.is_active = False

    def inspect_step(
        self,
        model: str,
        input_tokens: int,
        output_tokens: int,
        tool_name: Optional[str] = None,
    ) -> None:
        """Validate the next step before the agent continues executing."""

        if not self.is_active:
            return

        self.steps += 1
        if self.steps > self.max_steps:
            raise LoopDetectedError(
                f"TxVeto blocked execution: max steps ({self.max_steps}) reached."
            )

        price_info = PRICING.get(model, PRICING["gpt-4o-mini"])
        cost = (input_tokens * price_info["in"]) + (output_tokens * price_info["out"])
        self.spent_usd += cost

        print(
            f"Step {self.steps} | Model: {model} | Cost: ${cost:.5f} | "
            f"Total: ${self.spent_usd:.5f} / ${self.max_usd:.5f}"
        )

        if self.spent_usd > self.max_usd:
            raise BudgetExceededError(
                f"TxVeto VETO: budget ${self.max_usd:.2f} exceeded at ${self.spent_usd:.5f}."
            )

        if tool_name:
            self.tool_calls.append(tool_name)
            recent_calls = self.tool_calls[-self.loop_threshold :]
            if len(recent_calls) >= self.loop_threshold and len(set(recent_calls)) == 1:
                raise LoopDetectedError(
                    f"TxVeto VETO: AI agent got stuck in a loop calling '{tool_name}'."
                )
