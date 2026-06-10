# Indexer Event Contract (Step 4)

Use these events from `TxVetoSessionPolicy` for real-time budget status.

## Core events

- `SessionCreated(bytes32 sessionId, address owner, address sessionKey, uint64 validAfter, uint64 validUntil, uint64 periodSeconds, uint256 maxValuePerCall, uint256 maxValuePerPeriod, address spendToken, uint256 maxTokenPerCall, uint256 maxTokenPerPeriod)`
- `SessionCreatedBySignature(bytes32 sessionId, bytes32 digest, address relayer)`
- `SessionRevoked(bytes32 sessionId, address revokedBy)`
- `SessionExecuted(bytes32 sessionId, address sessionKey, address target, bytes4 selector, uint256 value, uint256 spentInWindow, uint64 nonce)`
- `SessionTokenExecuted(bytes32 sessionId, address sessionKey, address target, bytes4 selector, address token, uint256 tokenAmount, uint256 tokenSpentInWindow, uint64 nonce)`
- `SafeRouteExecuted(bytes32 sessionId, address smartAccount, address target, uint256 value)`
- `KernelRouteExecuted(bytes32 sessionId, address smartAccount, address target, uint256 value)`
- `SafeTokenRouteExecuted(bytes32 sessionId, address smartAccount, address target, uint256 tokenAmount)`
- `KernelTokenRouteExecuted(bytes32 sessionId, address smartAccount, address target, uint256 tokenAmount)`

## Derived projections

- Session state (`active`, owner, session key, validity window)
- Budget policy snapshot (native + token)
- Runtime spend (`spentInWindow`, `tokenSpentInWindow`, latest `nonce`)
- Target/selector usage distribution

## Minimal table sketch

- `sessions`
  - `session_id` (pk)
  - `owner`
  - `session_key`
  - `valid_after`
  - `valid_until`
  - `period_seconds`
  - `max_value_per_call`
  - `max_value_per_period`
  - `spend_token`
  - `max_token_per_call`
  - `max_token_per_period`
  - `active`
  - `updated_at_block`

- `session_executions`
  - `tx_hash`
  - `log_index`
  - `session_id`
  - `target`
  - `selector`
  - `value`
  - `token`
  - `token_amount`
  - `spent_in_window`
  - `token_spent_in_window`
  - `nonce`
  - `block_number`
  - `timestamp`
