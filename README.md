# TxVeto

TxVeto is an in-process budget and loop guard for AI agents. It is designed to stop runaway API spend and repeated tool-call loops before the next expensive call is made.

## Why TxVeto

Agentic systems fail fast when guardrails are missing. A prompt injection, loop bug, or tool misuse can trigger expensive cascades in minutes.

TxVeto adds runtime safety primitives you can enforce locally:

- Hard budget ceilings per run
- Max-step loop circuit breakers
- Repeated tool-call detection
- MCP policy controls for guarded tool execution

## What's included

- `txveto.guard.VetoGuard` for budget and loop enforcement
- `txveto.errors` for typed safety exceptions
- `txveto.policy.BudgetPolicy` for MCP policy configuration
- A browser playground in `txveto.web_demo`
- A JSON-RPC MCP server wrapper in `txveto.mcp_server`
- On-chain Step 4 thin slice in `onchain/contracts/TxVetoSessionPolicy.sol`
- Pytest coverage for wallet-drain and infinite-loop scenarios

## On-Chain Step 4 Thin Slice

The repository now includes an initial on-chain policy gateway under `onchain/`:

- Session-key based execution policy contract
- EIP-712 signed session creation support
- Time windows, per-call spend limits, and rolling period budgets
- Optional ERC20-denominated budget enforcement
- Safe/Kernel AA adapter routing through policy checks
- Target and function selector allowlists
- Execution-time policy enforcement
- Indexer-friendly events for create/revoke/execute lifecycle

See `onchain/README.md` and `onchain/indexer/EVENTS.md` for integration details.

## Install

### Local development

```bash
pip install -e .[dev]
pytest
```

### Package usage

```bash
# after publish
pip install txveto
```

## Quick Start

```bash
python -m txveto.demo --mode both
python -m txveto.web_demo
```

Installed console scripts:

- `txveto-demo --mode both`
- `txveto-web-demo`
- `txveto-mcp`

## Python API Example

```python
from txveto.guard import VetoGuard

guard = VetoGuard(max_usd=0.50, max_steps=10)

with guard:
    guard.inspect_step(
        model="claude-3-5-sonnet",
        input_tokens=50_000,
        output_tokens=2_000,
        tool_name="fetch_web_data",
    )
```

## MCP Tools

The MCP server exposes policy-aware tools for inspection and runtime configuration. `budget.configure` updates the active per-session policy, `budget.status` returns the current spend and policy snapshot, and `policy.evaluate` lets clients simulate a step before executing it.

## Launch Artifacts

- Changelog: `CHANGELOG.md`
- Release checklist: `RELEASE_CHECKLIST.md`

## License

MIT
