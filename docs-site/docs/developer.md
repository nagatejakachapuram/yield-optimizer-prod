# Developer Notes

These notes help contributors understand, test, and extend the protocol.

---

## Local Development

* Clone repo and run:

  ```bash
  forge install
  forge test
  pnpm install
  pnpm dev
  ```

* You need Sepolia ETH + USDC to test vault deposits.

* Use `MockAavePool`, `MockMorphoMarket` for strategy testing.

---

## Key Contracts

### VaultFactory

* Deploys `YVault` with proper strategy + AutomationOwner.
* Tracks vaults by risk level.

### YVault

* Implements ERC4626.
* Delegates execution to strategy via `allocateFunds()`.

### Strategies

* Each must implement `IStrategy` interface.
* Mock contracts available for testnet.

---

## Chainlink Automation Integration

* `AutomationOwner` contract owns vaults.
* Only Chainlink Keeper can call `updateVaultStrategy()`.
* Set keeper via `setKeeper(address)`.

---

## ElizaOS AI Agent

* Located in `eliza-ai-agnet/src/agent.ts`.
* Uses external APIs (CoinGecko, Aave, Morpho).
* Triggers strategy updates via KV writes.

---

## Testing Strategy Logic

You can simulate allocation by:

1. Deploying vault and strategy contracts.
2. Depositing USDC.
3. Manually calling `setStrategy()` and `allocateFunds()`.
4. Verifying fund movement in strategy contract.

---

## Extending the System

* Add new strategy by creating a contract that implements `IStrategy`.
* Register new strategy in your AI agent logic.
* Update frontend to reflect additional vaults or options.

---

See [architecture.md](architecture.md) and [api.md](api.md) for detailed references.
