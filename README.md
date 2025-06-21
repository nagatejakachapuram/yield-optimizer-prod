# AI-Powered Yield Vaults

This repo contains smart contracts and mocks for an AI-powered yield optimizer protocol. Users deposit USDC into vaults, choose a risk preference, and earn yield from selected pools via dynamically managed strategies. Strategy allocation is controlled by an AI agent and Chainlink Automation.

## Architecture Overview

### 🔹 YVault (Yearn-style Vault)

* File: `src/Contracts/YVault.sol`
* Holds user deposits and manages USDC balances.
* Integrates with a single strategy (low or high risk) approved by the admin.
* Tracks user shares and total assets.
* Calls `execute(address user, uint256 amount)` on the strategy.

### 🔹 VaultFactory

* File: `src/Contracts/VaultFactory.sol`
* Deploys vaults dynamically.
* Used to create separate vaults for low-risk and high-risk strategies.

### 🔹 Strategies

Strategies implement the `IStrategy` interface and execute deposits into specific yield pools.

* `LowRiskSAavestrategy.sol`

  * Deposits into mock Aave-like pool (via `MockAavePool.sol`).
  * Targets users selecting low risk.

* `HighRiskPendleStrategy.sol`

  * Deposits into mock Pendle pool (via `MockPendleMarket.sol`).
  * Targets users selecting high risk.

* `MockStrategy.sol`

  * Generic mock used for testing `YVault` integration.

### 🔹 Mocks

For testing strategy and pool behavior:

* `MockAavePool.sol`, `MockPendleMarket.sol` — simulate yield pools
* `MockPT.sol`, `MockYT.sol` — simulate Pendle Principal/Ownership tokens
* `MockPriceFeed.sol` — simulates Chainlink price feeds

## AI + Automation Flow

1. **User Deposit**

   * User deposits USDC via the frontend and selects a risk preference (low/high).
   * Funds are sent to the appropriate vault (`YVault`).

2. **AI Agent Analysis**

   * Off-chain AI agent fetches market and pool data (via CoinGecko, DefiLlama, Aave, Pendle, etc).
   * Chooses the optimal strategy for the given risk level.
   * Stores strategy address in ElizaOS KV store.

3. **Chainlink Automation**

   * Triggers `allocateFunds(user, amount, strategy)` on `YVault`.
   * Only callable by a `chainlink_admin` role.
   * Vault calls the strategy’s `execute()` method with USDC.

## Security

* 🔐 **Multi-sig admin**: All critical functions like strategy approval, pausing, and recovery are gated by multi-sig owner.
* 📜 **Proof-of-Reserves (PoR)**: Future versions will integrate PoR validation before allocations to off-chain strategies.
* 🛡 **Reentrancy protection** on vault operations.
* 🚫 **Pause functionality** for emergency halts.

## Interfaces

* `IStrategy`: Standardized interface all strategies must implement.

```solidity
interface IStrategy {
    function execute(address user, uint256 amount) external;
}
```

## Deployment (Local Testing)

```bash
forge build
forge test
```

## Coming Soon

* Chainlink Keeper integration script
* ElizaOS AI agent logic
* PoR enforcement module
* Real mainnet pool adapters (Aave, Pendle, etc.)

---

Maintained by AI Vaults team.

For questions or collaboration, reach out via Telegram or Discord.
