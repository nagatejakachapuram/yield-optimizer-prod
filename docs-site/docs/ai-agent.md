# AI Agent

The off-chain AI agent is built using ElizaOS. It analyzes market data and writes strategy decisions to ElizaOS KV storage, which Chainlink Automation later reads.

---

## Responsibilities

* Monitor market conditions (price trend, yield changes).
* Choose optimal pool (per risk profile).
* Store selected strategy per vault type in ElizaOS KV.

---

## Workflow

1. **User deposits USDC** and selects a risk preference.
2. **Vault logs deposit**, but does not allocate funds yet.
3. **AI agent periodically runs**, checks DeFi data (Aave, Morpho, Curve, Lookonchain, CoinGecko).
4. Based on market classification (e.g., bullish, sideways), AI picks the best `IStrategy` per risk profile.
5. Writes the decision to KV:

   ```json
   {
     "low": "0xLowRiskAaveStrategy",
     "high": "0xHighRiskMorphoStrategy"
   }
   ```
6. **Chainlink Automation** triggers and reads this KV.
7. Calls `AutomationOwner.updateVaultStrategy()`.
8. `YVault.allocateFunds()` then sends funds to the new strategy.

---

## Example Strategy Logic

* If stable yields > 4% and market is flat → use Aave.
* If ETH market up 7d/25d and Curve APY is high → use Curve.

---

## Extensibility

You can extend the AI agent to:

* Add more sources (e.g., Dune, Pendle).
* Customize thresholds.
* Combine user sentiment data.

---

See [developer.md](developer.md) for how to integrate more protocols or replace ElizaOS.
