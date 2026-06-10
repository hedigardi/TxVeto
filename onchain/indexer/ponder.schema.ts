import { onchainTable } from "ponder";

export const session = onchainTable("session", (t) => ({
  id: t.hex().primaryKey(),
  owner: t.hex().notNull(),
  sessionKey: t.hex().notNull(),
  active: t.boolean().notNull(),
  validAfter: t.integer().notNull(),
  validUntil: t.integer().notNull(),
  periodSeconds: t.integer().notNull(),
  maxValuePerCall: t.bigint().notNull(),
  maxValuePerPeriod: t.bigint().notNull(),
  spendToken: t.hex().notNull(),
  maxTokenPerCall: t.bigint().notNull(),
  maxTokenPerPeriod: t.bigint().notNull(),
  latestNonce: t.bigint().notNull(),
  nativeSpentInWindow: t.bigint().notNull(),
  tokenSpentInWindow: t.bigint().notNull(),
}));

export const sessionExecution = onchainTable("session_execution", (t) => ({
  id: t.text().primaryKey(),
  sessionId: t.hex().notNull(),
  txHash: t.hex().notNull(),
  blockNumber: t.bigint().notNull(),
  timestamp: t.integer().notNull(),
  target: t.hex().notNull(),
  selector: t.hex().notNull(),
  value: t.bigint().notNull(),
  token: t.hex().notNull(),
  tokenAmount: t.bigint().notNull(),
  nonce: t.bigint().notNull(),
  nativeSpentInWindow: t.bigint().notNull(),
  tokenSpentInWindow: t.bigint().notNull(),
}));
