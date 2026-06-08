from txveto.policy import BudgetPolicy
from txveto.scenarios import run_demo_scenarios


def test_budget_policy_validation_and_schema():
    policy = BudgetPolicy.from_arguments(
        {
            "max_usd": 2.5,
            "max_steps": 8,
            "loop_threshold": 4,
            "allowed_tools": ["fetch_web_data", "write_file"],
            "deny_unknown_tools": True,
        }
    )

    assert policy.max_usd == 2.5
    assert policy.max_steps == 8
    assert policy.loop_threshold == 4
    assert policy.allowed_tools == ("fetch_web_data", "write_file")
    assert policy.deny_unknown_tools is True
    assert BudgetPolicy.schema()["properties"]["allowed_tools"]["type"] == "array"


def test_demo_scenarios_return_both_results():
    payload = run_demo_scenarios("both")

    assert payload["mode"] == "both"
    assert payload["budget"]["status"] == "vetoed"
    assert payload["loop"]["status"] == "vetoed"
    assert payload["budget"]["steps"] >= 1
    assert payload["loop"]["steps"] >= 1
