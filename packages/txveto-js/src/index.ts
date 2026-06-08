export class TxVetoError extends Error {}

export class BudgetExceededError extends TxVetoError {}

export class LoopDetectedError extends TxVetoError {}

export type PricingTable = Record<string, { in: number; out: number }>;

export const PRICING: PricingTable = {
  "gpt-4o": { in: 2.5 / 1_000_000, out: 10.0 / 1_000_000 },
  "gpt-4o-mini": { in: 0.15 / 1_000_000, out: 0.6 / 1_000_000 },
  "claude-3-5-sonnet": { in: 3.0 / 1_000_000, out: 15.0 / 1_000_000 },
};

export interface InspectStepInput {
  model: string;
  inputTokens: number;
  outputTokens: number;
  toolName?: string;
}

export interface VetoGuardOptions {
  maxUsd: number;
  maxSteps?: number;
  loopThreshold?: number;
  pricing?: PricingTable;
}

export class VetoGuard {
  maxUsd: number;
  maxSteps: number;
  loopThreshold: number;
  spentUsd: number;
  steps: number;
  toolCalls: string[];
  isActive: boolean;
  pricing: PricingTable;

  constructor(options: VetoGuardOptions) {
    this.maxUsd = options.maxUsd;
    this.maxSteps = options.maxSteps ?? 15;
    this.loopThreshold = options.loopThreshold ?? 3;
    this.pricing = options.pricing ?? PRICING;
    this.spentUsd = 0;
    this.steps = 0;
    this.toolCalls = [];
    this.isActive = false;
  }

  start(): this {
    this.isActive = true;
    return this;
  }

  stop(): void {
    this.isActive = false;
  }

  inspectStep(input: InspectStepInput): void {
    if (!this.isActive) {
      return;
    }

    this.steps += 1;
    if (this.steps > this.maxSteps) {
      throw new LoopDetectedError(
        `TxVeto blocked execution: max steps (${this.maxSteps}) reached.`,
      );
    }

    const price = this.pricing[input.model] ?? this.pricing["gpt-4o-mini"];
    const cost = input.inputTokens * price.in + input.outputTokens * price.out;
    this.spentUsd += cost;

    if (this.spentUsd > this.maxUsd) {
      throw new BudgetExceededError(
        `TxVeto VETO: budget ${this.maxUsd.toFixed(2)} exceeded at ${this.spentUsd.toFixed(5)}.`,
      );
    }

    if (input.toolName) {
      this.toolCalls.push(input.toolName);
      const recent = this.toolCalls.slice(-this.loopThreshold);
      if (recent.length >= this.loopThreshold && new Set(recent).size === 1) {
        throw new LoopDetectedError(
          `TxVeto VETO: AI agent got stuck in a loop calling '${input.toolName}'.`,
        );
      }
    }
  }
}
