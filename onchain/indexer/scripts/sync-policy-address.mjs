import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(process.cwd(), "..");
const deploymentFile = process.env.TXVETO_DEPLOYMENT_FILE
  ? resolve(process.cwd(), process.env.TXVETO_DEPLOYMENT_FILE)
  : resolve(root, "deployments", "latest.json");

if (!existsSync(deploymentFile)) {
  throw new Error(`Deployment file not found: ${deploymentFile}`);
}

const deployment = JSON.parse(readFileSync(deploymentFile, "utf8"));
const policyAddress = deployment.policy;
const adapterAddress = deployment.adapter;

if (!policyAddress || !adapterAddress) {
  throw new Error("Deployment JSON must contain 'policy' and 'adapter'");
}

const envPath = resolve(process.cwd(), ".env.local");
const existing = {};

if (existsSync(envPath)) {
  const raw = readFileSync(envPath, "utf8");
  for (const line of raw.split(/\r?\n/)) {
    if (!line || line.startsWith("#")) continue;
    const idx = line.indexOf("=");
    if (idx <= 0) continue;
    const key = line.slice(0, idx).trim();
    const value = line.slice(idx + 1);
    existing[key] = value;
  }
}

const existingRpc = existing.PONDER_RPC_URL ?? "";
const existingStartBlock = existing.PONDER_START_BLOCK ?? "0";
const startBlock = process.env.TXVETO_START_BLOCK ?? existingStartBlock;

const lines = [
  `TXVETO_POLICY_ADDRESS=${policyAddress}`,
  `TXVETO_ADAPTER_ADDRESS=${adapterAddress}`,
  `PONDER_RPC_URL=${existingRpc}`,
  `PONDER_START_BLOCK=${startBlock}`,
];
writeFileSync(envPath, `${lines.join("\n")}\n`, "utf8");

console.log(`Wrote ${envPath}`);
console.log(`TXVETO_POLICY_ADDRESS=${policyAddress}`);
console.log(`TXVETO_ADAPTER_ADDRESS=${adapterAddress}`);
