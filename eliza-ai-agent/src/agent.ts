// agent.ts
// ====== Imports ======
// @ts-ignore: Will be available only in ElizaOS runtime
let kv: { set: (key: string, val: string) => Promise<void>; get?: (key: string) => Promise<string | null> }; // Added 'get' for completeness in case it's used elsewhere, though not directly in this file's main logic.

try {
  // Attempt to import the ElizaOS KV store
  const elizaKv = await import("@elizaos/kv");
  kv = {
    set: elizaKv.set,
    get: elizaKv.get // Ensure 'get' is also assigned if available from ElizaOS KV
  };
} catch (e) {
  // Fallback to local file-based KV if ElizaOS KV is not available (e.g., when running agent.ts directly for testing)
  console.warn(" Falling back to local KV for agent.ts");
  const fs = await import("fs/promises");
  kv = {
    set: async (key: string, val: string) => {
      await fs.writeFile(`.local-kv-${key}.json`, val, "utf-8");
    },
    get: async (key: string) => { // Added 'get' for the local fallback too
      try {
        return await fs.readFile(`.local-kv-${key}.json`, "utf-8");
      } catch (readError) {
        return null;
      }
    },
  };
}

import axios from "axios";

// ====== Types ======
type RiskLevel = "low" | "high";

interface PoolInfo {
  address: string;
  apy: number;
  platform: string;
  asset: string;
}

interface StrategyResult {
  timestamp: number;
  trend: "uptrend" | "downtrend";
  risk: RiskLevel;
  selectedPool: PoolInfo;
}

// ====== Constants ======
const DEFILLAMA_API = process.env.DEFILLAMA_API || "https://yields.llama.fi"; // Reads from env, with a fallback
const COINGECKO_API = process.env.COINGECKO_API || "https://api.coingecko.com/api/v3";
const USDC_CG_ID = "usd-coin";
const DAYS_LOOKBACK = 25;

// ====== Trend Detection ======
async function isDowntrend(assetId: string): Promise<boolean> {
  const url = `${COINGECKO_API}/coins/${assetId}/market_chart?vs_currency=usd&days=${DAYS_LOOKBACK}`;
  const res = await axios.get(url);
  const prices = res.data.prices.map((p: any) => p[1]);

  if (prices.length < 8) throw new Error("Not enough price history for trend detection");

  const current = prices[prices.length - 1];
  const day7 = prices[prices.length - 8]; // 7 days ago
  const day25 = prices[0]; // 25 days ago

  return current < day7 && current < day25;
}

// ====== Yield Fetchers ======
async function getDefiLlamaYields(): Promise<any[]> {
  const res = await axios.get(`${DEFILLAMA_API}/pools`);
  return res.data.data;
}

async function getBestLowRiskPool(): Promise<PoolInfo | null> {
  const yields = await getDefiLlamaYields();

  return yields
    .filter(y =>
      y.project?.toLowerCase().includes("aave") &&
      y.apyBase &&
      y.symbol?.toLowerCase() === 'usdc'
    )
    .map(y => ({
      address: y.pool,
      apy: y.apyBase,
      apyBps: Math.round(y.apyBase * 10000),
      platform: "Aave",
      asset: y.symbol,
    }))
    .sort((a, b) => b.apy - a.apy)[0] || null;
}

async function getBestHighRiskPool(): Promise<PoolInfo | null> {
  const yields = await getDefiLlamaYields();

  return yields
    .filter(y =>
      y.project?.toLowerCase().includes("morpho") &&
      y.apyBase &&
      y.symbol?.toLowerCase() === 'usdc'
    )
    .map(y => ({
      address: y.pool,
      apy: y.apyBase,
      apyBps: Math.round(y.apyBase * 10000),
      platform: "Morpho",
      asset: y.symbol,
    }))
    .sort((a, b) => b.apy - a.apy)[0] || null;
}


// ====== Run for a given risk level ======
async function runForRisk(risk: RiskLevel) {
  try {
    const downtrend = await isDowntrend(USDC_CG_ID);
    const trend: "uptrend" | "downtrend" = downtrend ? "downtrend" : "uptrend";

    const bestPool =
      risk === "low" ? await getBestLowRiskPool() : await getBestHighRiskPool();

    if (!bestPool) {
      console.warn(` No ${risk}-risk pool found.`);
      return;
    }

    const result: StrategyResult = {
      timestamp: Date.now(),
      trend,
      risk,
      selectedPool: bestPool,
    };

    await kv.set(`strategy:${risk}`, JSON.stringify(result));
    console.log(` Stored ${risk}-risk strategy:`, result);

  } catch (err) {
    console.error(` Failed to process ${risk} strategy:`, err);
  }
}

// ====== Main Runner ======
export async function main() {
  await runForRisk("low");
  await runForRisk("high");
}

// ====== Run Periodically or Once ======
// This block ensures the agent logic runs when agent.ts is executed directly,
// or when imported and called by src/index.ts. The setInterval is appropriate here.
if (import.meta.url === `file://${process.argv[1]}`) {
  const INTERVAL_MS = 15 * 60 * 1000; // 15 minutes

  console.log(" Eliza strategy agent started (15 min interval)");

  // Initial run
  await main();

  // Run every 15 mins (only if long-running process like `node agent.js`)
  setInterval(() => {
    main().catch(err => console.error("Agent error:", err));
  }, INTERVAL_MS);
}