import { createConfig } from "ponder";

// Replace with your deployed contract address.
const policyAddress = (process.env.TXVETO_POLICY_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;
const adapterAddress = (process.env.TXVETO_ADAPTER_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;

export default createConfig({
  chains: {
    baseSepolia: {
      id: 84532,
      rpc: process.env.PONDER_RPC_URL,
      pollingInterval: 4_000,
      maxRequestsPerSecond: 5,
    },
  },
  contracts: {
    TxVetoSessionPolicy: {
      chain: "baseSepolia",
      abi: [
        {
          type: "event",
          name: "SessionCreated",
          inputs: [
            { name: "sessionId", type: "bytes32", indexed: true },
            { name: "owner", type: "address", indexed: true },
            { name: "sessionKey", type: "address", indexed: true },
            { name: "validAfter", type: "uint64", indexed: false },
            { name: "validUntil", type: "uint64", indexed: false },
            { name: "periodSeconds", type: "uint64", indexed: false },
            { name: "maxValuePerCall", type: "uint256", indexed: false },
            { name: "maxValuePerPeriod", type: "uint256", indexed: false },
            { name: "spendToken", type: "address", indexed: false },
            { name: "maxTokenPerCall", type: "uint256", indexed: false },
            { name: "maxTokenPerPeriod", type: "uint256", indexed: false },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "SessionRevoked",
          inputs: [
            { name: "sessionId", type: "bytes32", indexed: true },
            { name: "revokedBy", type: "address", indexed: true },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "SessionExecuted",
          inputs: [
            { name: "sessionId", type: "bytes32", indexed: true },
            { name: "sessionKey", type: "address", indexed: true },
            { name: "target", type: "address", indexed: true },
            { name: "selector", type: "bytes4", indexed: false },
            { name: "value", type: "uint256", indexed: false },
            { name: "spentInWindow", type: "uint256", indexed: false },
            { name: "nonce", type: "uint64", indexed: false },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "SessionTokenExecuted",
          inputs: [
            { name: "sessionId", type: "bytes32", indexed: true },
            { name: "sessionKey", type: "address", indexed: true },
            { name: "target", type: "address", indexed: true },
            { name: "selector", type: "bytes4", indexed: false },
            { name: "token", type: "address", indexed: false },
            { name: "tokenAmount", type: "uint256", indexed: false },
            { name: "tokenSpentInWindow", type: "uint256", indexed: false },
            { name: "nonce", type: "uint64", indexed: false },
          ],
          anonymous: false,
        },
      ],
      address: policyAddress,
      startBlock: Number(process.env.PONDER_START_BLOCK ?? "0"),
    },
    TxVetoAARouterAdapter: {
      chain: "baseSepolia",
      abi: [
        {
          type: "event",
          name: "SafeRouteExecuted",
          inputs: [
            { name: "sessionId", type: "bytes32", indexed: true },
            { name: "smartAccount", type: "address", indexed: true },
            { name: "target", type: "address", indexed: true },
            { name: "value", type: "uint256", indexed: false },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "KernelRouteExecuted",
          inputs: [
            { name: "sessionId", type: "bytes32", indexed: true },
            { name: "smartAccount", type: "address", indexed: true },
            { name: "target", type: "address", indexed: true },
            { name: "value", type: "uint256", indexed: false },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "SafeTokenRouteExecuted",
          inputs: [
            { name: "sessionId", type: "bytes32", indexed: true },
            { name: "smartAccount", type: "address", indexed: true },
            { name: "target", type: "address", indexed: true },
            { name: "tokenAmount", type: "uint256", indexed: false },
          ],
          anonymous: false,
        },
        {
          type: "event",
          name: "KernelTokenRouteExecuted",
          inputs: [
            { name: "sessionId", type: "bytes32", indexed: true },
            { name: "smartAccount", type: "address", indexed: true },
            { name: "target", type: "address", indexed: true },
            { name: "tokenAmount", type: "uint256", indexed: false },
          ],
          anonymous: false,
        },
      ],
      address: adapterAddress,
      startBlock: Number(process.env.PONDER_START_BLOCK ?? "0"),
    },
  },
});
