# TxVeto Launch Posts (English)

## X / Twitter

If you let AI agents run tools without runtime circuit breakers, you are one prompt-injection away from expensive mistakes.

We just open-sourced **TxVeto**: in-process budget + loop guardrails for agent execution.

- Python package + MCP server
- Budget ceilings, step caps, loop detection
- Browser playground demo

Try it:

- `pip install txveto` (after release)
- `python -m txveto.demo --mode both`

Repo: https://github.com/hedigardi/TxVeto

## Farcaster

Shipped a new open-source safety layer for AI agents: **TxVeto**.

It stops runaway cost loops before the next expensive step is executed.

Includes:

- Python guard library
- MCP policy tools (`budget.inspect`, `budget.configure`, `budget.status`, `policy.evaluate`)
- Browser playground for prompt-injection scenarios

Would love feedback from anyone running LangGraph/CrewAI style loops.

Repo: https://github.com/hedigardi/TxVeto

## Reddit (`r/LangChain`, `r/LocalLLM`, `r/ethdev`)

Title:
I got tired of runaway agent loops draining API budgets, so I open-sourced TxVeto

Body:
I kept seeing AI-agent runs spiral into expensive loops after tool misuse or prompt-injection, so I built a small runtime guard called **TxVeto**.

What it does:

- Enforces max budget per run
- Stops execution after max steps
- Detects repeated tool loops and vetoes early
- Exposes MCP tools for policy control

It is intentionally lightweight and runs in-process.

Repo + demo:
https://github.com/hedigardi/TxVeto

If useful, I can add first-party wrappers for your preferred framework.
