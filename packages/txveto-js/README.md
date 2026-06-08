# txveto-js

Minimal JavaScript/TypeScript runtime guard for AI-agent budget and loop safety.

## Install

```bash
npm install txveto-js
```

## Usage

```ts
import { VetoGuard } from "txveto-js";

const guard = new VetoGuard({
  maxUsd: 0.5,
  maxSteps: 10,
  loopThreshold: 3,
}).start();

guard.inspectStep({
  model: "claude-3-5-sonnet",
  inputTokens: 50_000,
  outputTokens: 2_000,
  toolName: "fetch_web_data",
});
```
