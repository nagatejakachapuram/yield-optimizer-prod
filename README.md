
# 🧠 AI-Driven Yield Vault

A sophisticated smart contract vault system designed to automate **USDC** yield optimization. It combines user-defined risk preferences with an **AI agent** and **Chainlink Automation** to dynamically allocate funds to the most optimal yield-generating strategies within a chosen risk class.

---

## 🚀 How It Works

This system operates on a multi-layered approach to maximize user yields while adhering to their specified risk appetite:

### 1. User Deposit & Initial Setup

* Users deposit **USDC** into the **Vault** contract via the `deposit()` function.
* Alternatively, users can deposit **USDY** via `swapUSDYtoUSDC()`, which the Vault internally converts to USDC using a `MockSwap` service.
* Users then explicitly set their **risk preference** by calling `StrategyManager.setUserStrategy()`, choosing between the `LowRiskStrategy` or `HighRiskStrategy` router contracts.

### 2. Idle Funds

* Once deposited, user funds remain in the **Vault**, tracked by `userDeposits`, until the AI agent initiates an allocation.

### 3. AI Agent Decision & Off-Chain Communication

* An **off-chain AI agent** constantly analyzes market conditions, on-chain data, and the **user's chosen risk preference** (retrieved from `StrategyManager`).
* When the AI determines the most optimal yield strategy for a user's funds within their selected risk class, it communicates this decision to a secure off-chain backend service.

### 4. Chainlink Automation Trigger

* **Chainlink Automation** monitors the off-chain backend service for new allocation decisions.
* Upon detecting a signal, Chainlink Automation triggers the **Vault's `allocateFunds()` function**. This call includes the user's address, the amount to allocate, and the address of the user's chosen router strategy (`LowRiskStrategy` or `HighRiskStrategy`). The `chainlink_Admin` role ensures secure execution of this step.

### 5. Fund Allocation (Vault to Router Strategy)

* The `Vault` contract verifies the allocation details, ensures the selected router strategy is approved, and deducts the amount from the user's balance.
* It then securely transfers the **USDC** directly to the chosen router strategy (`LowRiskStrategy` or `HighRiskStrategy`).
* Finally, the Vault calls the `execute()` function on this router strategy, passing the user's address and the amount.

### 6. Fund Routing (Router Strategy to Concrete Pool)

* The **router strategy** (e.g., `LowRiskStrategy`) receives the funds.
* It then delegates the funds to its currently configured `activePool` (e.g., `AaveStrategy` for low-risk funds, or `PendleStrategy` for high-risk funds).
* The router strategy approves its `activePool` to spend the USDC and calls the `execute()` function on the concrete pool strategy.

### 7. Yield Generation (Concrete Pool)

* The **concrete strategy** (e.g., `AaveStrategy` or `PendleStrategy`) receives the USDC.
* It then interacts directly with the specified DeFi protocol (e.g., Aave's lending pool or a Pendle market) to deploy the funds and begin generating yield on behalf of the user.

---

## 📂 Contracts Overview

| Contract            | Description                                                                                                                                     |
| :------------------ | :---------------------------------------------------------------------------------------------------------------------------------------- |
| `Vault.sol`         | The core entry point. Handles **USDC** and **USDY** deposits, withdrawals, and securely allocates funds to approved router strategies based on Chainlink Automation triggers. Manages total value locked. |
| `StrategyManager.sol` | Manages user risk preferences, allowing users to select between `LowRiskStrategy` and `HighRiskStrategy`. Also allows admin to update these router strategy addresses.           |
| `LowRiskStrategy.sol` | A **router strategy** for low-risk investments. It receives funds from the Vault and forwards them to its configured `activePool` (e.g., `AaveStrategy`).                                         |
| `HighRiskStrategy.sol`| A **router strategy** for high-risk investments. It receives funds from the Vault and forwards them to its configured `activePool` (e.g., `PendleStrategy`).                                        |
| `AaveStrategy.sol`  | A **concrete strategy** that directly supplies funds to the Aave lending protocol to earn yield.                                                                           |
| `PendleStrategy.sol`| A **concrete strategy** that directly interacts with a higher-risk DeFi protocol (e.g., Pendle) to deposit funds into a specific market.                                            |
| `MockSwap.sol`      | (Interface) Simulates a swap service for converting USDY to USDC within the Vault.                                                                         |
| `IStrategy.sol`     | (Interface) Defines the common `execute` function for all strategies.                                                                                     |

---

## ⚙️ Components & Roles

* **Users**: Deposit USDC or USDY, explicitly choose their general risk preference (`low` or `high`), and can initiate withdrawals.
* **AI Agent**: An off-chain entity that continuously analyzes market data and user risk choices to identify and signal optimal allocation opportunities.
* **Chainlink Automation**: Monitors the AI's signals and triggers the `Vault`'s `allocateFunds()` function on-chain. This critical role is managed by the designated `chainlink_Admin` address in the Vault.
* **Admin**: The owner of the Vault and StrategyManager. The Admin is responsible for approving new strategies, pausing/unpausing the Vault in emergencies, recovering accidentally sent tokens, and securely transferring admin ownership.

---

## 🔐 Security Features

* **Reentrancy Protection**: Employs OpenZeppelin's `ReentrancyGuard` to prevent re-entrant attacks on critical state-changing functions.
* **Pausable**: Implements OpenZeppelin's `Pausable` functionality, allowing the Admin to temporarily halt core Vault operations during emergencies or upgrades.
* **Safe ERC20 Operations**: Utilizes OpenZeppelin's `SafeERC20` library for robust and secure ERC20 token interactions, mitigating common token transfer vulnerabilities.
* **Whitelisted Strategies**: Funds can only be allocated from the Vault to strategies that have been explicitly approved and whitelisted by the Admin.
* **Role Separation**: Distinct access controls for the Admin and Chainlink Automation (`chainlink_Admin`) ensure clear responsibilities and enhance the system's security posture.
* **Emergency Recovery**: An Admin-only function (`recoverERC20`) is available to retrieve ERC20 tokens accidentally sent to the Vault, excluding the primary assets (USDC, USDY) to prevent misuse.

---

## 🛠️ Deployment

To deploy and set up the AI-Driven Yield Vault, follow these steps in sequence:

### Deployment Order:

1.  Deploy `Vault.sol`
2.  Deploy `StrategyManager.sol`
3.  Deploy `LowRiskStrategy.sol`
4.  Deploy `HighRiskStrategy.sol`
5.  Deploy `AaveStrategy.sol`
6.  Deploy `PendleStrategy.sol` 

### Post-Deployment Configuration:

1.  **Set Router Strategies in `StrategyManager`**:
    * The Admin calls `StrategyManager.setLowRiskStrategy(<address_of_LowRiskStrategy>)`
    * The Admin calls `StrategyManager.setHighRiskStrategy(<address_of_HighRiskStrategy>)`
2.  **Set Concrete Pools in Router Strategies**:
    * The Admin calls `LowRiskStrategy.setActivePool(<address_of_AaveStrategy>)`
    * The Admin calls `HighRiskStrategy.setActivePool(<address_of_PendleStrategy>)`
3.  **Approve Router Strategies in `Vault`**:
    * The Admin calls `Vault.setApprovedStrategy(<address_of_LowRiskStrategy>, true)`
    * The Admin calls `Vault.setApprovedStrategy(<address_of_HighRiskStrategy>, true)`
4.  **Set Chainlink Admin in `Vault`**:
    * The Admin calls `Vault.setChainlinkAdmin(<address_of_chainlink_automation_wallet>)`
5.  **Off-chain Setup**:
    * Configure your AI agent to analyze data and make allocation decisions.
    * Set up Chainlink Automation to monitor your backend service and trigger the `Vault.allocateFunds()` function on-chain with the correct parameters.

---

## 📜 License

MIT

---

### Project Flow Summary:

1.  **User Entry**: A user **deposits USDC** (or **USDY, which is internally swapped to USDC**) into the **`Vault.sol`** contract.
2.  **User Risk Selection**: The user then **explicitly chooses their general risk appetite** by calling `StrategyManager.setUserStrategy()`, pointing to either the deployed **`LowRiskStrategy.sol`** or **`HighRiskStrategy.sol`** contract. These are the **router strategies** for their respective risk profiles.
3.  **AI Analysis & Decision**: An **off-chain AI agent** constantly monitors market conditions and meticulously respects the user's chosen risk strategy (data retrieved from `StrategyManager`). When the AI identifies an optimal time and specific underlying pool (e.g., Aave, Pendle) within the user's selected risk profile, it signals an allocation.
4.  **Chainlink Automation Trigger**: **Chainlink Automation**, acting on the AI's signal and controlled by the `chainlink_Admin` role, calls `Vault.allocateFunds(user, amount, user's_chosen_router_strategy_address)`.
5.  **Vault Allocation**: The `Vault` verifies the request, deducts the amount from the user's balance, and **transfers the USDC directly** to the `execute()` function of the specified **router strategy** (either `LowRiskStrategy` or `HighRiskStrategy`).
6.  **Router Strategy Delegation**: The **router strategy** (e.g., `LowRiskStrategy`) receives the USDC. It then **approves and calls the `execute()` function on its currently active concrete pool strategy** (which the admin would have pre-configured, e.g., `AaveStrategy.sol` or `PendleStrategy.sol`).
7.  **Concrete Pool Yield Generation**: The **concrete pool strategy** (`AaveStrategy.sol` or `PendleStrategy.sol`) receives the USDC and proceeds to **interact directly with the underlying DeFi protocol** (Aave or Pendle) to supply the funds and begin generating yield.