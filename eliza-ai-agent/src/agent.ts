// @ts-ignore
import { kv } from "@elizaos/kv";
import axios from "axios";

// ====== Types ======
type RiskLevel = "low" | "high";

interface PoolInfo {
  address: string;
  apy: number;
  platform: string;
  asset: string;
}

// ====== Config ======
const COINGECKO_API = "https://api.coingecko.com/api/v3";
const DEFILLAMA_API = "https://yields.llama.fi";
const USDC_CG_ID = "usd-coin";
const DAYS_LOOKBACK = 25;

// ====== CoinGecko: Market Trend ======
async function isDowntrend(assetId: string): Promise<boolean> {
  const url = `${COINGECKO_API}/coins/${assetId}/market_chart?vs_currency=usd&days=${DAYS_LOOKBACK}`;
  const res = await axios.get(url);
  const prices = res.data.prices.map((p: any) => p[1]);

  const current = prices[prices.length - 1];
  const day7 = prices[prices.length - 8];
  const day25 = prices[0];

  return current < day7 && current < day25;
}

// ====== DefiLlama Yields ======
async function getDefiLlamaYields(): Promise<any[]> {
  const res = await axios.get(`${DEFILLAMA_API}/v2/yield/usdc`);
  return res.data;
}

// ====== Aave Pools (Low Risk) ======
async function getBestLowRiskPool(): Promise<PoolInfo | null> {
  const yields = await getDefiLlamaYields();

  const aavePools = yields
    .filter(y => y.project.toLowerCase().includes("aave") && y.apyBase)
    .map(y => ({
      address: y.pool,
      apy: y.apyBase,
      platform: "Aave",
      asset: y.symbol,
    }))
    .sort((a, b) => b.apy - a.apy);

  return aavePools[0] || null;
}

// ====== Pendle Pools (High Risk) ======
async function getBestHighRiskPool(): Promise<PoolInfo | null> {
  const yields = await getDefiLlamaYields();

  const pendlePools = yields
    .filter(y => y.project.toLowerCase().includes("pendle") && y.apyBase)
    .map(y => ({
      address: y.pool,
      apy: y.apyBase,
      platform: "Pendle",
      asset: y.symbol,
    }))
    .sort((a, b) => b.apy - a.apy);

  return pendlePools[0] || null;
}

// ====== Main Agent Logic ======
export async function main(risk: RiskLevel = "low") {
  try {
    const downtrend = await isDowntrend(USDC_CG_ID);
    const trend = downtrend ? "downtrend" : "uptrend";

    let bestPool: PoolInfo | null = null;
    if (risk === "low") {
      bestPool = await getBestLowRiskPool();
    } else {
      bestPool = await getBestHighRiskPool();
    }

    if (!bestPool) {
      console.warn("⚠️ No suitable pool found.");
      return;
    }

    const result = {
      timestamp: Date.now(),
      trend,
      risk,
      selectedPool: bestPool,
    };

    await kv.set(`strategy:${risk}`, JSON.stringify(result));
    console.log(`✅ Strategy stored for '${risk}':`, result);
  } catch (err) {
    console.error("❌ Agent failed:", err);
  }
}
export async function runAgent() {
  // ... AI agent logic we wrote before
}
