# Changelog

## 0.1.1 - Unreleased

- Bumped Python package version to `0.1.1`.
- Bumped JavaScript package version to `0.1.1`.
- Expanded `.gitignore` to exclude local virtualenvs and `node_modules` directories.

## 0.1.0 - 2026-06-08

- Initial public MVP release.
- Added `VetoGuard` budget and loop protections.
- Added typed exceptions (`BudgetExceededError`, `LoopDetectedError`, `PolicyViolationError`).
- Added MCP JSON-RPC server with policy tools (`budget.inspect`, `budget.configure`, `budget.status`, `policy.evaluate`).
- Added CLI demo (`txveto-demo`) and browser playground (`txveto-web-demo`).
- Added tests for guard behavior, MCP behavior, policy helpers, and web demo payloads.
