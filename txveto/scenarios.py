"""Shared demo scenarios for the TxVeto CLI and web demo."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict

from .errors import BudgetExceededError, LoopDetectedError
from .guard import VetoGuard


@dataclass(slots=True)
class DemoOutcome:
    name: str
    status: str
    steps: int
    spent_usd: float
    message: str

    def to_dict(self) -> Dict[str, Any]:
        return {
            "name": self.name,
            "status": self.status,
            "steps": self.steps,
            "spent_usd": round(self.spent_usd, 6),
            "message": self.message,
        }


@dataclass(slots=True)
class TranscriptLine:
    role: str
    title: str
    message: str

    def to_dict(self) -> Dict[str, str]:
        return {
            "role": self.role,
            "title": self.title,
            "message": self.message,
        }


def _simulate_run(guard: VetoGuard, inject_loop: bool) -> None:
    with guard:
        for i in range(1, 20):
            tool_name = "fetch_web_data" if inject_loop else f"action_{i}"
            guard.inspect_step(
                model="claude-3-5-sonnet",
                input_tokens=50_000,
                output_tokens=2_000,
                tool_name=tool_name,
            )


def run_budget_scenario() -> DemoOutcome:
    guard = VetoGuard(max_usd=0.50, max_steps=10)
    try:
        _simulate_run(guard, inject_loop=False)
    except BudgetExceededError as exc:
        return DemoOutcome("budget", "vetoed", guard.steps, guard.spent_usd, str(exc))
    return DemoOutcome("budget", "allowed", guard.steps, guard.spent_usd, "Budget remained within limits.")


def run_loop_scenario() -> DemoOutcome:
    guard = VetoGuard(max_usd=100.00, max_steps=15, loop_threshold=3)
    try:
        _simulate_run(guard, inject_loop=True)
    except LoopDetectedError as exc:
        return DemoOutcome("loop", "vetoed", guard.steps, guard.spent_usd, str(exc))
    return DemoOutcome("loop", "allowed", guard.steps, guard.spent_usd, "No loop detected.")


def run_demo_scenarios(mode: str) -> Dict[str, Any]:
    results: Dict[str, Any] = {"mode": mode}
    if mode in {"budget", "both"}:
        results["budget"] = run_budget_scenario().to_dict()
    if mode in {"loop", "both"}:
        results["loop"] = run_loop_scenario().to_dict()
    return results


def build_transcript(mode: str, attack_prompt: str, entries: list[Dict[str, str]], summary: Dict[str, str]) -> list[Dict[str, str]]:
    transcript: list[TranscriptLine] = [
        TranscriptLine(role="user", title="Prompt injection", message=attack_prompt),
        TranscriptLine(role="agent", title="Planner", message="I will follow the requested workflow and prepare the next tool calls."),
        TranscriptLine(role="guard", title="TxVeto", message="Budget and loop checks are active before every expensive step."),
    ]

    for entry in entries:
        role = "guard" if entry["kind"].endswith("veto") else "agent"
        transcript.append(
            TranscriptLine(role=role, title=entry["kind"], message=entry["message"])
        )

    transcript.append(
        TranscriptLine(
            role="guard",
            title="Outcome",
            message=f"{summary['status'].upper()}: {summary['detail']}",
        )
    )
    return [line.to_dict() for line in transcript]
