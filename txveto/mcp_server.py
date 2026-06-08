"""Minimal JSON-RPC MCP-style server wrapper for TxVeto."""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from typing import Any, Dict

from .errors import LoopDetectedError, PolicyViolationError
from .guard import VetoGuard
from .policy import BudgetPolicy, build_policy_from_payload


@dataclass
class MCPContext:
    guard: VetoGuard
    policy: BudgetPolicy


def get_mcp_context(guard: VetoGuard) -> MCPContext:
    existing = getattr(guard, "_txveto_mcp_context", None)
    if isinstance(existing, MCPContext):
        return existing

    context = MCPContext(
        guard=guard,
        policy=BudgetPolicy(
            max_usd=guard.max_usd,
            max_steps=guard.max_steps,
            loop_threshold=guard.loop_threshold,
        ),
    )
    setattr(guard, "_txveto_mcp_context", context)
    return context


def _jsonrpc_result(request_id: Any, result: Dict[str, Any]) -> str:
    return json.dumps({"jsonrpc": "2.0", "id": request_id, "result": result})


def _jsonrpc_error(request_id: Any, code: int, message: str) -> str:
    return json.dumps(
        {
            "jsonrpc": "2.0",
            "id": request_id,
            "error": {"code": code, "message": message},
        }
    )


def _tool_definitions() -> list[Dict[str, Any]]:
    return [
        {
            "name": "budget.inspect",
            "description": "Inspect the next agent step against the active TxVeto budget policy.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "model": {"type": "string"},
                    "input_tokens": {"type": "integer", "minimum": 0},
                    "output_tokens": {"type": "integer", "minimum": 0},
                    "tool_name": {"type": "string"},
                },
                "required": ["model", "input_tokens", "output_tokens"],
                "additionalProperties": False,
            },
        },
        {
            "name": "budget.configure",
            "description": "Update the active TxVeto budget policy for the session.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "max_usd": {"type": "number", "minimum": 0},
                    "max_steps": {"type": "integer", "minimum": 1},
                    "loop_threshold": {"type": "integer", "minimum": 1},
                    "allowed_tools": {
                        "type": "array",
                        "items": {"type": "string"},
                    },
                    "deny_unknown_tools": {"type": "boolean"},
                },
                "additionalProperties": False,
            },
        },
        {
            "name": "budget.status",
            "description": "Return the current budget policy and runtime state.",
            "inputSchema": {
                "type": "object",
                "properties": {},
                "additionalProperties": False,
            },
        },
        {
            "name": "policy.evaluate",
            "description": "Evaluate a candidate step without mutating the guard state.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "model": {"type": "string"},
                    "input_tokens": {"type": "integer", "minimum": 0},
                    "output_tokens": {"type": "integer", "minimum": 0},
                    "tool_name": {"type": "string"},
                },
                "required": ["model", "input_tokens", "output_tokens"],
                "additionalProperties": False,
            },
        },
    ]


def _status_payload(context: MCPContext) -> Dict[str, Any]:
    return {
        "policy": context.policy.to_dict(),
        "runtime": {
            "spent_usd": round(context.guard.spent_usd, 6),
            "steps": context.guard.steps,
            "is_active": context.guard.is_active,
            "tool_calls": list(context.guard.tool_calls),
        },
    }


def handle_mcp_request(guard: VetoGuard, request_str: str) -> str:
    try:
        context = get_mcp_context(guard)
        req = json.loads(request_str)
        method = req.get("method")
        request_id = req.get("id")
        params = req.get("params", {})

        if method == "initialize":
            return _jsonrpc_result(
                request_id,
                {
                    "protocolVersion": "2024-11-05",
                    "serverInfo": {"name": "txveto", "version": "0.1.0"},
                    "capabilities": {"tools": {"listChanged": False}},
                },
            )

        if method == "tools/list":
            return _jsonrpc_result(request_id, {"tools": _tool_definitions()})

        if method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments", {})
            if tool_name == "budget.configure":
                context.policy = build_policy_from_payload(arguments, context.policy)
                context.guard.max_usd = context.policy.max_usd
                context.guard.max_steps = context.policy.max_steps
                context.guard.loop_threshold = context.policy.loop_threshold
                return _jsonrpc_result(
                    request_id,
                    {
                        "content": [
                            {
                                "type": "text",
                                "text": f"TxVeto policy updated: {json.dumps(context.policy.to_dict())}",
                            }
                        ]
                    },
                )

            if tool_name == "budget.status":
                return _jsonrpc_result(
                    request_id,
                    {
                        "content": [
                            {
                                "type": "text",
                                "text": json.dumps(_status_payload(context)),
                            }
                        ]
                    },
                )

            if tool_name == "policy.evaluate":
                model = arguments.get("model", "gpt-4o-mini")
                input_tokens = int(arguments.get("input_tokens", 1000))
                output_tokens = int(arguments.get("output_tokens", 200))
                candidate_tool = arguments.get("tool_name")
                projected_cost = context.policy.estimate_cost(model, input_tokens, output_tokens)
                projected_steps = context.guard.steps + 1
                projected_spend = context.guard.spent_usd + projected_cost
                allowed = True
                reasons = []

                if projected_steps > context.policy.max_steps:
                    allowed = False
                    reasons.append("max_steps_exceeded")
                if projected_spend > context.policy.max_usd:
                    allowed = False
                    reasons.append("budget_exceeded")
                if not context.policy.allows_tool(candidate_tool):
                    allowed = False
                    reasons.append("tool_not_allowed")

                return _jsonrpc_result(
                    request_id,
                    {
                        "content": [
                            {
                                "type": "text",
                                "text": json.dumps(
                                    {
                                        "allowed": allowed,
                                        "reasons": reasons,
                                        "projected_cost": round(projected_cost, 6),
                                        "projected_spend": round(projected_spend, 6),
                                    }
                                ),
                            }
                        ]
                    },
                )

            if not context.policy.allows_tool(arguments.get("tool_name", tool_name)):
                raise LoopDetectedError(
                    f"TxVeto VETO: tool '{arguments.get('tool_name', tool_name)}' is not allowed by policy."
                )

            context.guard.inspect_step(
                model=arguments.get("model", "gpt-4o-mini"),
                input_tokens=int(arguments.get("input_tokens", 1000)),
                output_tokens=int(arguments.get("output_tokens", 200)),
                tool_name=arguments.get("tool_name", tool_name),
            )
            return _jsonrpc_result(
                request_id,
                {
                    "content": [
                        {
                            "type": "text",
                            "text": f"TxVeto approved execution of {tool_name}.",
                        }
                    ]
                },
            )

        return _jsonrpc_error(request_id, -32601, "Unsupported MCP method.")
    except Exception as exc:
        return _jsonrpc_error(None, -32000, str(exc))


def main() -> None:
    session_guard = VetoGuard(max_usd=1.00, max_steps=10)
    session_guard.__enter__()
    print("TxVeto MCP server running on stdin/stdout...", file=sys.stderr)

    for line in sys.stdin:
        payload = line.strip()
        if not payload:
            continue
        response = handle_mcp_request(session_guard, payload)
        print(response, flush=True)


if __name__ == "__main__":
    main()
