"""Budget policy primitives for TxVeto demos and MCP tools."""

from __future__ import annotations

from dataclasses import dataclass, replace
from typing import Any, Dict, Mapping, Sequence, Tuple

from .errors import PolicyViolationError
from .guard import PRICING


@dataclass(frozen=True)
class BudgetPolicy:
    max_usd: float = 1.0
    max_steps: int = 10
    loop_threshold: int = 3
    allowed_tools: Tuple[str, ...] = ()
    deny_unknown_tools: bool = False

    def update(self, **changes: object) -> "BudgetPolicy":
        return replace(self, **changes)

    def validate(self) -> None:
        if self.max_usd <= 0:
            raise PolicyViolationError("Policy max_usd must be greater than zero.")
        if self.max_steps <= 0:
            raise PolicyViolationError("Policy max_steps must be greater than zero.")
        if self.loop_threshold <= 0:
            raise PolicyViolationError("Policy loop_threshold must be greater than zero.")
        if any(not isinstance(tool, str) or not tool for tool in self.allowed_tools):
            raise PolicyViolationError("Policy allowed_tools must contain only non-empty strings.")

    def to_dict(self) -> Dict[str, object]:
        return {
            "max_usd": self.max_usd,
            "max_steps": self.max_steps,
            "loop_threshold": self.loop_threshold,
            "allowed_tools": list(self.allowed_tools),
            "deny_unknown_tools": self.deny_unknown_tools,
        }

    def allows_tool(self, tool_name: str | None) -> bool:
        if not tool_name:
            return True
        if not self.allowed_tools:
            return True
        if not self.deny_unknown_tools:
            return True
        return tool_name in self.allowed_tools

    def estimate_cost(self, model: str, input_tokens: int, output_tokens: int) -> float:
        price_info = PRICING.get(model, PRICING["gpt-4o-mini"])
        return (input_tokens * price_info["in"]) + (output_tokens * price_info["out"])

    @classmethod
    def from_arguments(cls, arguments: Mapping[str, Any]) -> "BudgetPolicy":
        allowed_tools = arguments.get("allowed_tools", ())
        if allowed_tools is None:
            allowed_tools = ()
        if not isinstance(allowed_tools, Sequence) or isinstance(allowed_tools, (str, bytes)):
            raise PolicyViolationError("Policy allowed_tools must be a list or tuple of strings.")

        policy = cls(
            max_usd=float(arguments.get("max_usd", 1.0)),
            max_steps=int(arguments.get("max_steps", 10)),
            loop_threshold=int(arguments.get("loop_threshold", 3)),
            allowed_tools=tuple(str(tool) for tool in allowed_tools),
            deny_unknown_tools=bool(arguments.get("deny_unknown_tools", False)),
        )
        policy.validate()
        return policy

    @classmethod
    def schema(cls) -> Dict[str, Any]:
        return {
            "type": "object",
            "properties": {
                "max_usd": {"type": "number", "minimum": 0},
                "max_steps": {"type": "integer", "minimum": 1},
                "loop_threshold": {"type": "integer", "minimum": 1},
                "allowed_tools": {"type": "array", "items": {"type": "string"}},
                "deny_unknown_tools": {"type": "boolean"},
            },
            "additionalProperties": False,
        }


def build_policy_from_payload(payload: Dict[str, object], base: BudgetPolicy) -> BudgetPolicy:
    merged = {
        "max_usd": payload.get("max_usd", base.max_usd),
        "max_steps": payload.get("max_steps", base.max_steps),
        "loop_threshold": payload.get("loop_threshold", base.loop_threshold),
        "allowed_tools": payload.get("allowed_tools", list(base.allowed_tools)),
        "deny_unknown_tools": payload.get("deny_unknown_tools", base.deny_unknown_tools),
    }
    return BudgetPolicy.from_arguments(merged)
