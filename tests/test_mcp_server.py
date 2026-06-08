import json

from txveto.guard import VetoGuard
from txveto.mcp_server import handle_mcp_request


def test_initialize_returns_jsonrpc_payload():
    guard = VetoGuard(max_usd=1.00)

    response = json.loads(
        handle_mcp_request(
            guard,
            json.dumps({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {}}),
        )
    )

    assert response["jsonrpc"] == "2.0"
    assert response["id"] == 1
    assert response["result"]["serverInfo"]["name"] == "txveto"
    assert "tools" in response["result"]["capabilities"]


def test_tools_call_returns_content_and_respects_guard():
    guard = VetoGuard(max_usd=1.00, max_steps=2)

    with guard:
        response = json.loads(
            handle_mcp_request(
                guard,
                json.dumps(
                    {
                        "jsonrpc": "2.0",
                        "id": 2,
                        "method": "tools/call",
                        "params": {
                            "name": "budget.inspect",
                            "arguments": {
                                "model": "gpt-4o-mini",
                                "input_tokens": 1000,
                                "output_tokens": 200,
                                "tool_name": "fetch_web_data",
                            },
                        },
                    }
                ),
            )
        )

    assert response["jsonrpc"] == "2.0"
    assert response["id"] == 2
    assert response["result"]["content"][0]["text"] == "TxVeto approved execution of budget.inspect."
    assert guard.steps == 1


def test_tools_list_exposes_policy_tools():
    guard = VetoGuard(max_usd=1.00)

    response = json.loads(
        handle_mcp_request(
            guard,
            json.dumps({"jsonrpc": "2.0", "id": 3, "method": "tools/list", "params": {}}),
        )
    )

    tool_names = {tool["name"] for tool in response["result"]["tools"]}
    assert {"budget.inspect", "budget.configure", "budget.status", "policy.evaluate"}.issubset(tool_names)


def test_budget_configure_updates_session_policy():
    guard = VetoGuard(max_usd=1.00, max_steps=10)

    with guard:
        response = json.loads(
            handle_mcp_request(
                guard,
                json.dumps(
                    {
                        "jsonrpc": "2.0",
                        "id": 4,
                        "method": "tools/call",
                        "params": {
                            "name": "budget.configure",
                            "arguments": {
                                "max_usd": 0.25,
                                "max_steps": 4,
                                "loop_threshold": 2,
                                "allowed_tools": ["fetch_web_data"],
                                "deny_unknown_tools": True,
                            },
                        },
                    }
                ),
            )
        )

    assert guard.max_usd == 0.25
    assert guard.max_steps == 4
    assert guard.loop_threshold == 2
    assert "allowed_tools" in response["result"]["content"][0]["text"]

