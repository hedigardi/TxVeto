# TxVeto On-Chain Step 4 (Thin Slice)

This folder contains the first on-chain validation slice for TxVeto.

## What is implemented

- `contracts/TxVetoSessionPolicy.sol`
  - Session-key based execution gateway
  - EIP-712 signed session creation (`createSessionWithSig`)
  - Time-bounded session windows (`validAfter`, `validUntil`)
  - Per-call spend limit (`maxValuePerCall`)
  - Rolling period budget limit (`maxValuePerPeriod` over `periodSeconds`)
  - Optional ERC20-denominated spend policy (`spendToken`, token per-call/per-period)
  - Target allowlist and selector-level permissions
  - Execution-time policy enforcement
  - Indexer-friendly events for create/revoke/native-execute/token-execute

- `contracts/TxVetoAARouterAdapter.sol`
  - Safe/Kernel adapter routing through TxVeto policy execution
  - Separate route events for native and token paths

- `script/DeployTxVeto.s.sol`
  - Deploys both policy + adapter
  - Writes `deployments/latest.json` with deployed addresses

- `test/TxVetoSessionPolicy.t.sol`
  - Foundry-style thin-slice tests for signature-based session creation
  - Native value execution path
  - ERC20 execution path and period budget rejection

- `indexer/`
  - Ponder starter config and schema
  - Event handlers for session lifecycle and execution projections

## Why execution-time checks

For AA environments, complex dynamic policy checks in pre-validation can be brittle.
This thin slice enforces dynamic policy in the execution path to reduce pre-sim constraints and avoid false rejections from strict simulation assumptions.

## Event model (for indexer)

- `SessionCreated`
- `SessionCreatedBySignature`
- `SessionRevoked`
- `SessionExecuted`
- `SessionTokenExecuted`

These events are enough to derive:

- Active sessions
- Session configuration history
- Spend consumed per session window
- Real execution volume by target/selector

## Run locally

1. Foundry tests

```bash
cd onchain
forge test
```

Deploy (after setting `DEPLOYER_PRIVATE_KEY` and RPC URL):

```bash
cd onchain
forge script script/DeployTxVeto.s.sol:DeployTxVeto --rpc-url $RPC_URL --broadcast
```

2. Indexer starter

```bash
cd onchain/indexer
npm install
npm run sync:env
npm run dev
```

Required env vars:

- `PONDER_RPC_URL`
- `TXVETO_POLICY_ADDRESS`
- `TXVETO_ADAPTER_ADDRESS`
- `PONDER_START_BLOCK` (optional)

`npm run sync:env` reads `onchain/deployments/latest.json` and writes `onchain/indexer/.env.local`.

## Suggested next steps

1. Add signature nonce partitioning per owner and per chain strategy in client SDK.
2. Add Safe/Kernel adapter contract for account-abstraction-native routing.
3. Add integration tests for rollover timing, revoke race conditions, and replay resistance.
4. Add policy version hashing and migration support for signed payload compatibility.
