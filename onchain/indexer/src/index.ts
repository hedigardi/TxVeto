import { ponder } from "ponder:registry";

ponder.on("TxVetoSessionPolicy:SessionCreated", async ({ event, context }) => {
  const { Session } = context.db;

  await Session.upsert({
    id: event.args.sessionId,
    create: {
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
    },
    update: {
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
    },
  });
});

ponder.on("TxVetoSessionPolicy:SessionRevoked", async ({ event, context }) => {
  const { Session } = context.db;
  await Session.update({
    id: event.args.sessionId,
    data: {
      active: false,
    },
  });
});

ponder.on("TxVetoSessionPolicy:SessionExecuted", async ({ event, context }) => {
  const { SessionExecution, Session } = context.db;
  const executionId = `${event.transaction.hash}-${event.log.logIndex}`;

  await SessionExecution.create({
    id: executionId,
    data: {
      sessionId: event.args.sessionId,
      txHash: event.transaction.hash,
      blockNumber: event.block.number,
      timestamp: Number(event.block.timestamp),
      target: event.args.target,
      selector: event.args.selector,
      value: event.args.value,
      token: "0x0000000000000000000000000000000000000000",
      tokenAmount: 0n,
      nonce: BigInt(event.args.nonce),
      nativeSpentInWindow: event.args.spentInWindow,
      tokenSpentInWindow: 0n,
    },
  });

  await Session.update({
    id: event.args.sessionId,
    data: {
      latestNonce: BigInt(event.args.nonce),
      nativeSpentInWindow: event.args.spentInWindow,
    },
  });
});

ponder.on(
  "TxVetoSessionPolicy:SessionTokenExecuted",
  async ({ event, context }) => {
    const { SessionExecution, Session } = context.db;
    const executionId = `${event.transaction.hash}-${event.log.logIndex}`;

    await SessionExecution.create({
      id: executionId,
      data: {
        sessionId: event.args.sessionId,
        txHash: event.transaction.hash,
        blockNumber: event.block.number,
        timestamp: Number(event.block.timestamp),
        target: event.args.target,
        selector: event.args.selector,
        value: 0n,
        token: event.args.token,
        tokenAmount: event.args.tokenAmount,
        nonce: BigInt(event.args.nonce),
        nativeSpentInWindow: 0n,
        tokenSpentInWindow: event.args.tokenSpentInWindow,
      },
    });

    await Session.update({
      id: event.args.sessionId,
      data: {
        latestNonce: BigInt(event.args.nonce),
        tokenSpentInWindow: event.args.tokenSpentInWindow,
      },
    });
  },
);
