-----

# AI- VAULT Protocol Documentation

This section provides an overview of the core smart contract interfaces: `YVault`, `IStrategy`, and `AutomationOwner`.

-----

## 🔒 YVault Core Contract

The central component for managing deposited assets and shares.

### ⚙️ Functions

#### `deposit(uint256 assets, address receiver)`

  * **Description:** Allows users to deposit a specified `assets` amount (e.g., USDC) into the vault.
  * **Behavior:** Mints and transfers corresponding vault shares to the `receiver` address.

#### `withdraw(uint256 assets, address receiver, address owner)`

  * **Description:** Enables users to burn a specified amount of shares to redeem `assets` (e.g., USDC) from the vault.
  * **Behavior:** Transfers the redeemed `assets` to the `receiver` address.

#### `setStrategy(address newStrategy)`

  * **Description:** Updates the active strategy contract that the vault utilizes for deploying funds.
  * **Access Control:** Callable **only** by the `AutomationOwner`.

#### `allocateFunds(address user, uint256 amount)`

  * **Description:** Instructs the currently active strategy to deploy a specific `amount` of deposited funds.
  * **Behavior:** Internally calls `strategy.execute(user, amount)`.
  * **Access Control:** Callable **only** by the `AutomationOwner`.

#### `pricePerShare()`

  * **Description:** Returns the current exchange rate between vault shares and the underlying asset (e.g., USDC).
  * **Returns:** `uint256` representing the share-to-asset ratio.

-----

## 🎯 IStrategy Interface

```solidity
interface IStrategy {
    function execute(address user, uint256 amount) external;
}
```

  * **Purpose:** Defines the standard interface for strategy contracts.
  * **Role:** Each strategy decides how to deploy the funds allocated by the `YVault` (e.g., lending to Aave, providing liquidity to Curve, etc.). Strategies are responsible for maximizing returns from the deposited assets.

-----

## 🤖 AutomationOwner Contract

This contract serves as a delegated authority, primarily for Chainlink Automation, to safely manage `YVault` logic.

### 🌟 Purpose

  * Acts as the sole authorized entity to call sensitive functions on the `YVault`, such as `setStrategy` and `allocateFunds`.
  * Crucial for enabling decentralized and automated management of `YVault` operations through Chainlink Automation.

### ⚙️ Functions

#### `updateVaultStrategy(address vault, address newStrategy)`

  * **Description:** Facilitates the update of a `YVault`'s active strategy.
  * **Access Control:** Callable **only** by the Chainlink Automation Keeper.
  * **Behavior:** Internally calls `vault.setStrategy(newStrategy)` on the specified `vault` contract.

#### `setKeeper(address newKeeper)`

  * **Description:** Allows the owner to update the authorized Chainlink Keeper address.
  * **Access Control:** Callable **only** by the contract owner.

-----

## 🔑 Access Control Summary

  * **Vault Owner:** The initial deployer of the `YVault` contract. This ownership may be transferred to a new address after deployment.
  * **AutomationOwner:** Holds the exclusive authority to manage the execution and strategic deployment of funds within the `YVault`. This is the single point of control for dynamic vault management.
  * **Strategy Contracts:** These contracts have no special access rights within the `YVault` or `AutomationOwner`. They are passive recipients of funds and instructions, solely responsible for their defined deployment logic.

-----

For a deeper understanding of how these components interact, please refer to the [architecture.md](architecture.md) document. If you're looking to customize or extend the protocol's functionality, consult the [developer-docs.md](developer-docs.md) guide.