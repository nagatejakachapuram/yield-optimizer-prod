
# 🤖 AI Agent

The off-chain AI agent is a core intelligence layer of the Yield Optimizer protocol, built using **ElizaOS**. It continuously monitors DeFi markets and computes the most suitable strategy based on user risk preferences. The output is stored in ElizaOS Key-Value (KV) storage and accessed by **Chainlink Automation** to update vault strategy allocations.

---

## 🎯 Core Responsibilities

The AI agent is responsible for:

* **Real-Time Market Analysis**: Continuously monitors DeFi market trends, stablecoin yields, and platform-specific APYs using data from sources like CoinGecko, Aave, Morpho, Curve, Defillama and Lookonchain.
* **Strategy Selection**: Determines the optimal yield pool based on current market conditions and predefined risk profiles (e.g., low, high).
* **KV Storage of Recommendations**: Outputs structured strategy recommendations and stores them under designated keys (e.g., `low.json`, `high.json`) in ElizaOS KV storage.

---

## 🚀 Workflow Overview

The integration between the AI agent, YVault smart contracts, and Chainlink Automation follows this lifecycle:

1. **User Deposit & Risk Selection**
   Users deposit USDC into a `YVault` contract and select a preferred risk level (e.g., low or high).

2. **Vault Records Deposit**
   The `YVault` registers the deposit but does not immediately allocate funds to a strategy.

3. **Periodic AI Execution**
   The AI agent runs periodically (e.g., every few hours), gathering real-time DeFi data from platforms like Aave, Morpho, Curve, and CoinGecko.

4. **Market Classification & Strategy Selection**
   The agent classifies the market (e.g., uptrend, downtrend, sideways) and chooses the most appropriate pool for each risk level.

5. **Result Storage in KV**
   The selected strategy is stored in ElizaOS KV under separate keys (e.g., `low.json`, `high.json`) in the following JSON format:

   ```json
   {
     "timestamp": 1751090934932,
     "trend": "uptrend",
     "risk": "high",
     "selectedPool": {
       "address": "363b9e0e-28c4-4153-9fff-f2f9ac2d3a3c",
       "apy": 6.84981,
       "platform": "Morpho",
       "asset": "USDC"
     }
   }
   ```

6. **Chainlink Automation Trigger**
   A Chainlink Automation Keeper monitors the KV store. When a new strategy update is detected, it triggers the `AutomationOwner.updateVaultStrategy()` function.

7. **Vault Fund Allocation**
   After the vault strategy is updated, `YVault.allocateFunds()` is invoked to allocate both new and idle funds into the selected on-chain strategy.

---

## 💡 Example Decision Logic

The AI agent’s decision-making process can be configured with various logic models. Some examples include:

* **Stable Yields + Sideways Market**: In periods of market stability and consistent yields (e.g., >4%), the AI may allocate low-risk users to Aave lending markets.
* **Bullish Trends + High APY**: In an uptrend scenario, with surging ETH prices and attractive stablecoin yields on Morpho, the AI may choose a high-risk Morpho strategy.

---

## 🔌 Extensibility

The AI agent is designed with flexibility and future-proofing in mind:

* **New Data Sources**: Easily integrate additional data providers such as Pendle, Dune Analytics, or custom smart contract analytics.
* **Custom Risk Rules**: Modify thresholds (e.g., volatility, APY floors) to fine-tune how strategies are selected per market regime.
* **Sentiment & Social Data**: Extend logic to include social indicators or sentiment analysis from platforms like X (Twitter) or Discord.

---

For details on expanding protocol support or customizing the ElizaOS integration, refer to the [developer-docs.md](developer-docs.md) guide.

