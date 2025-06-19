// src/agent.ts
import axios from "axios";
var kv;
try {
  kv = await import("@elizaos/kv");
} catch (e) {
  console.warn("\u26A0\uFE0F Falling back to local KV");
  const fs = await import("fs/promises");
  kv = {
    set: async (key, val) => {
      await fs.writeFile(`.local-kv-${key}.json`, val, "utf-8");
    }
  };
}
var DEFILLAMA_API = "https://yields.llama.fi";
var COINGECKO_API = "https://api.coingecko.com/api/v3";
var USDC_CG_ID = "usd-coin";
var DAYS_LOOKBACK = 25;
async function isDowntrend(assetId) {
  const url = `${COINGECKO_API}/coins/${assetId}/market_chart?vs_currency=usd&days=${DAYS_LOOKBACK}`;
  const res = await axios.get(url);
  const prices = res.data.prices.map((p) => p[1]);
  if (prices.length < 8) throw new Error("Not enough price history for trend detection");
  const current = prices[prices.length - 1];
  const day7 = prices[prices.length - 8];
  const day25 = prices[0];
  return current < day7 && current < day25;
}
async function getDefiLlamaYields() {
  const res = await axios.get(`${DEFILLAMA_API}/pools`);
  return res.data.data;
}
async function getBestLowRiskPool() {
  const yields = await getDefiLlamaYields();
  return yields.filter(
    (y) => y.project?.toLowerCase().includes("aave") && y.apyBase && y.symbol?.toLowerCase() === "usdc"
    // ADD THIS LINE for USDC consistency
  ).map((y) => ({
    address: y.pool,
    apy: y.apyBase,
    platform: "Aave",
    asset: y.symbol
  })).sort((a, b) => b.apy - a.apy)[0] || null;
}
async function getBestHighRiskPool() {
  const yields = await getDefiLlamaYields();
  return yields.filter(
    (y) => y.project?.toLowerCase().includes("pendle") && y.apyBase && y.symbol?.toLowerCase() === "usdc"
    // ADD THIS LINE for USDC consistency
  ).map((y) => ({
    address: y.pool,
    apy: y.apyBase,
    platform: "Pendle",
    asset: y.symbol
  })).sort((a, b) => b.apy - a.apy)[0] || null;
}
async function main(risk = "low") {
  try {
    const downtrend = await isDowntrend(USDC_CG_ID);
    const trend = downtrend ? "downtrend" : "uptrend";
    const bestPool = risk === "low" ? await getBestLowRiskPool() : await getBestHighRiskPool();
    if (!bestPool) {
      console.warn("\u26A0\uFE0F No suitable pool found.");
      return;
    }
    const result = {
      timestamp: Date.now(),
      trend,
      risk,
      selectedPool: bestPool
    };
    await kv.set(`strategy:${risk}`, JSON.stringify(result));
    console.log(`\u2705 Stored ${risk} strategy:`, result);
  } catch (err) {
    console.error("\u274C Agent failed:", err);
  }
}
if (import.meta.url === `file://${process.argv[1]}`) {
  main("low");
}

// src/index.ts
async function startApplication() {
  try {
    await main();
    console.log("Agent started successfully!");
  } catch (error) {
    console.error("AI agent failed:", error);
  }
}
startApplication();
//# sourceMappingURL=chunk-KCJFYBIN.js.map