# AI-Powered Yield Vaults

This repository contains the full stack of smart contracts, strategy interfaces, and mock infrastructure for an AI-powered yield optimization protocol built on top of ERC4626-style Yearn V2 vaults. Users can deposit USDC into vaults, select a risk preference (low or high), and earn yield via dynamically allocated strategies managed off-chain by an AI agent. Strategy selection and execution are triggered on-chain through Chainlink Automation, enabling a modular, intelligent, and secure DeFi yield platform.

---

## 🏗 Architecture Overview

### 🔹 `YVault.sol` (Yearn V2-Style Vault)
* Location: `src/Contracts/YVault.sol`
* ERC4626-like vault architecture managing USDC deposits.
* Tracks total assets and user shares.
* Integrated with a single active strategy, either low or high risk, configurable via `VaultFactory`.
* Supports `deposit()`, `withdraw()`, and AI-driven `allocateFunds(user, amount, strategy)` function (callable only by `chainlink_admin`).
* Internal fund routing through strategy interface `IStrategy`.
* Includes reentrancy protection, admin controls, token recovery, and emergency pause.

### 🔹 `VaultFactory.sol`
* Location: `src/Contracts/VaultFactory.sol`
* Deploys `YVault` instances dynamically based on risk profiles.
* Associates each deployed vault with either a low-risk or high-risk strategy at creation.
* Tracks all deployed vaults.

### 🔹 Strategy Contracts (Composable Yield Allocators)

All strategies implement the `IStrategy` interface and define custom execution logic for yield generation based on user risk preference.

#### ✅ `LowRiskAaveStrategy.sol`
* Integrates with `MockAavePool.sol`.
* Targeted for users selecting "Low Risk".
* USDC is deposited into a mock Aave-style pool.
* Strategy calculates yield based on a dynamic APY (basis points passed during deployment).

#### ✅ `HighRiskMorphoStrategy.sol`
* Integrates with `MockMorpho.sol` (previously `MockPendleMarket`).
* Targeted for users selecting "High Risk".
* USDC is allocated to a mock Morpho-style lending/borrowing pool.
* Supports real-time APY input during contract instantiation.

#### 🧪 `MockStrategy.sol`
* Simplified strategy for testing vault mechanics.
* Does not perform real yield generation.

### 🔹 Mocks (Simulated Pool Environments)

Mocks allow local testing and simulation of real DeFi protocols:

* `MockAavePool.sol`: Simulates yield accrual using time-weighted APY.
* `MockMorpho.sol`: Simulates yield accrual similarly with isolated balance tracking.
* `MockPriceFeed.sol`: Simulated Chainlink price feed.

---

## 🔁 AI + Chainlink Automation Workflow

### 1️⃣ **User Deposit via Frontend**
* User deposits USDC into `YVault` using frontend interface.
* Selects either "Low Risk" or "High Risk" strategy.
* Funds are deposited into the corresponding vault created via `VaultFactory`.

### 2️⃣ **AI Agent Strategy Selection**
* An off-chain agent (powered by ElizaOS + AI rules) fetches data from:
  - CoinGecko
  - DefiLlama
  - Aave / Morpho APIs
  - Historical price trends (7d / 25d)
* Based on market trend and pool APY, the agent selects the most optimal pool for the user’s selected risk level.
* Chosen strategy address and metadata (APY, platform, asset) are stored in ElizaOS's `.local-kv-strategy:{risk}.json`.

### 3️⃣ **Chainlink Automation Trigger**
* Chainlink Automation invokes `allocateFunds(user, amount, strategy)` on the `YVault`.
* The vault checks `msg.sender` has `chainlink_admin` role.
* Funds are routed to the specified `IStrategy.allocate()` method.

---

## 🔒 Security Considerations

* ✅ **Multi-sig Admin Access**
  - Strategy approval, pausing, and recovery restricted to `admin` role.

* ✅ **Reentrancy Protection**
  - `nonReentrant` modifiers on key external functions (`deposit`, `withdraw`, `allocateFunds`).

* ✅ **Chainlink Admin Role**
  - Separate `chainlink_admin` for automation triggers.

* ✅ **SafeERC20 Transfers**
  - Secure USDC handling using OpenZeppelin libraries.

* 🚨 **Emergency Pause**
  - Admins can pause the protocol to prevent deposits and withdrawals.

* 🔐 **Token Recovery**
  - Admins can recover non-core tokens mistakenly sent to the vault.

* 📊 **Upgradeable Strategy Routing**
  - Each strategy contract (e.g. `HighRiskMorphoStrategy`) can dynamically switch between pools.

---

## 🧩 Interfaces

```solidity
interface IStrategy {
    function execute(address user, uint256 amount) external;
}
```

---

## 🧪 Local Deployment & Testing

### Prerequisites
* Foundry (`forge`)
* Node.js (for frontend AI agent)
* ElizaOS local KV store

### Run Contracts
```bash
forge build
forge test
```

### Run Frontend AI Agent
```bash
node agent.js
```

---



