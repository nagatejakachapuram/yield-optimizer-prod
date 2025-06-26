
-----

# 🤖 AI Agent: Off-Chain Market Intelligence

The off-chain AI agent is a critical component built using **ElizaOS**. Its primary role is to analyze real-time market data and determine optimal strategy decisions, which are then stored in ElizaOS Key-Value (KV) storage for consumption by Chainlink Automation.

-----

## 🎯 Responsibilities

The AI agent is engineered to perform the following core functions:

  * **Market Monitoring:** Continuously observes and analyzes market conditions, including price trends and changes in decentralized finance (DeFi) yields.
  * **Optimal Pool Selection:** Identifies and selects the most suitable DeFi liquidity pools or protocols based on predefined risk profiles.
  * **Strategy Storage:** Persists the chosen strategy address for each vault type (e.g., based on risk profile) in the ElizaOS KV storage.

-----

## 🚀 Workflow Overview

The AI agent integrates seamlessly into the YVault protocol's operations through the following steps:

1.  **User Deposit & Risk Selection:** A user deposits USDC into a `YVault` and specifies their desired risk preference (e.g., low, high).

2.  **Vault Logs Deposit:** The `YVault` contract registers the deposit but *does not immediately allocate* the funds to a strategy.

3.  **AI Agent Execution:** The AI agent runs periodically (e.g., every few hours or once a day). During its execution, it queries various DeFi data sources such as Aave, Morpho, Curve, Lookonchain, and CoinGecko.

4.  **Strategy Selection:** Based on its market classification (e.g., bullish, bearish, sideways, volatile), the AI selects the most appropriate `IStrategy` contract address for each defined risk profile.

5.  **Decision Storage in KV:** The AI agent writes its strategy decisions to the ElizaOS KV store in a structured JSON format.

    ```json
    {
      "low": "0xLowRiskAaveStrategyAddress",
      "high": "0xHighRiskMorphoStrategyAddress",
      "medium": "0xMediumRiskCurveStrategyAddress" // Example of additional profiles
    }
    ```

6.  **Chainlink Automation Trigger:** A Chainlink Automation Keeper monitors the ElizaOS KV store. Upon detecting an updated strategy decision, it triggers its execution.

7.  **Strategy Update Call:** The Chainlink Automation Keeper calls `AutomationOwner.updateVaultStrategy()`, passing the new strategy address for the relevant `YVault`.

8.  **Fund Allocation:** Subsequently, `YVault.allocateFunds()` is invoked, which then directs the newly deposited funds (and potentially rebalances existing ones) to the newly set optimal strategy.

-----

## 💡 Example Strategy Logic

The AI agent's decision-making can be configured with diverse logic. Here are some illustrative examples:

  * **Stable Market/Yields:** If stablecoin yields consistently exceed 4% and the overall market remains flat or sideways, the agent might choose a low-risk strategy utilizing **Aave** for lending.
  * **Bullish ETH/High APY:** If the Ethereum market shows a strong upward trend over a 7-day or 25-day period and **Aave Protocol** pools offer particularly high APYs, the agent might select a strategy focused on Aave liquidity provision.

-----

## 🔌 Extensibility

The AI agent is designed with extensibility in mind, allowing for continuous improvement and adaptation:

  * **Additional Data Sources:** Integrate more data providers such as Dune Analytics, Pendle Finance, or custom on-chain data.
  * **Custom Thresholds:** Fine-tune the decision-making logic by adjusting yield thresholds, market movement percentages, and other parameters.
  * **User Sentiment Integration:** Incorporate external data on user sentiment or social media trends to inform strategic decisions.

-----

For detailed instructions on how to integrate more DeFi protocols or replace the underlying ElizaOS framework, please refer to the [developer-docs.md](developer-docs.md) guide.