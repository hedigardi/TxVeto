import { ponder } from "ponder:registry";
import { session, sessionExecution } from "ponder:schema";

ponder.on("TxVetoSessionPolicy:SessionCreated", async ({ event, context }) => {
  await context.db
    .insert(session)
    .values({
      id: event.args.sessionId,
      owner: event.args.owner,
      sessionKey: event.args.sessionKey,
      active: true,
      validAfter: Number(event.args.validAfter),
      validUntil: Number(event.args.validUntil),
      periodSeconds: Number(event.args.periodSeconds),
      maxValuePerCall: event.args.maxValuePerCall,
      maxValuePerPeriod: event.args.maxValuePerPeriod,
      spendToken: event.args.spendToken,
      maxTokenPerCall: event.args.maxTokenPerCall,
      maxTokenPerPeriod: event.args.maxTokenPerPeriod,
      latestNonce: 0n,
      nativeSpentInWindow: 0n,
      tokenSpentInWindow: 0n,
    })
    .onConflictDoUpdate((row) => ({
      owner: event.args.owner,
      sessionKey: event.args.sessionKey,
      active: true,
      validAfter: Number(event.args.validAfter),
      validUntil: Number(event.args.validUntil),
      periodSeconds: Number(event.args.periodSeconds),
      maxValuePerCall: event.args.maxValuePerCall,
      maxValuePerPeriod: event.args.maxValuePerPeriod,
      spendToken: event.args.spendToken,
      maxTokenPerCall: event.args.maxTokenPerCall,
      maxTokenPerPeriod: event.args.maxTokenPerPeriod,
      latestNonce: row.latestNonce,
      nativeSpentInWindow: row.nativeSpentInWindow,
      tokenSpentInWindow: row.tokenSpentInWindow,
    }));
});

ponder.on("TxVetoSessionPolicy:SessionRevoked", async ({ event, context }) => {
  await context.db
    .update(session, { id: event.args.sessionId })
    .set({ active: false });
});

ponder.on("TxVetoSessionPolicy:SessionExecuted", async ({ event, context }) => {
  const executionId = `${event.transaction.hash}-${event.log.logIndex}`;

  await context.db.insert(sessionExecution).values({
    id: executionId,
    sessionId: event.args.sessionId,
    txHash: event.transaction.hash,
    blockNumber: event.block.number,
    timestamp: Number(event.block.timestamp),
    target: event.args.target,
    selector: event.args.selector,
    value: event.args.value,
    token: "0x0000000000000000000000000000000000000000",
    tokenAmount: 0n,
    nonce: event.args.nonce,
    nativeSpentInWindow: event.args.spentInWindow,
    tokenSpentInWindow: 0n,
  });

  await context.db.update(session, { id: event.args.sessionId }).set({
    latestNonce: event.args.nonce,
    nativeSpentInWindow: event.args.spentInWindow,
  });
});

ponder.on(
  "TxVetoSessionPolicy:SessionTokenExecuted",
  async ({ event, context }) => {
    const executionId = `${event.transaction.hash}-${event.log.logIndex}`;

    await context.db.insert(sessionExecution).values({
      id: executionId,
      sessionId: event.args.sessionId,
      txHash: event.transaction.hash,
      blockNumber: event.block.number,
      timestamp: Number(event.block.timestamp),
      target: event.args.target,
      selector: event.args.selector,
      value: 0n,
      token: event.args.token,
      tokenAmount: event.args.tokenAmount,
      nonce: event.args.nonce,
      nativeSpentInWindow: 0n,
      tokenSpentInWindow: event.args.tokenSpentInWindow,
    });

    await context.db.update(session, { id: event.args.sessionId }).set({
      latestNonce: event.args.nonce,
      tokenSpentInWindow: event.args.tokenSpentInWindow,
    });
  },
);
