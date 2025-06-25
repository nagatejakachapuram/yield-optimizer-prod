# Vault API

This section documents the core smart contract interfaces: `YVault`, `IStrategy`, and `AutomationOwner`.

---

## YVault (ERC4626-style)

### Functions

#### `deposit(uint256 assets, address receiver)`

* Deposits USDC into the vault.
* Mints and transfers shares to `receiver`.

#### `withdraw(uint256 assets, address receiver, address owner)`

* Burns shares to redeem `assets` amount.
* Transfers USDC to `receiver`.

#### `setStrategy(address newStrategy)`

* Sets the active strategy (only callable by `AutomationOwner`).

#### `allocateFunds(address user, uint256 amount)`

* Calls `strategy.execute(user, amount)` to allocate deposited funds.
* Callable only by `AutomationOwner`.

#### `pricePerShare()`

* Returns share-to-asset exchange rate.

---

## IStrategy Interface

```solidity
interface IStrategy {
    function execute(address user, uint256 amount) external;
}
```

* The strategy decides how to deploy funds (e.g., lend to Aave, deposit in Curve).

---

## AutomationOwner

### Purpose

* Delegated authority for Chainlink Automation.
* Allows `updateVaultStrategy()` to safely manage `YVault` logic.

### Functions

#### `updateVaultStrategy(address vault, address newStrategy)`

* Callable only by Chainlink Automation Keeper.
* Internally calls `vault.setStrategy(newStrategy)`.

#### `setKeeper(address newKeeper)`

* Owner-only function to update authorized Chainlink keeper.

---

## Access Control

* Vault owner: initially deployer, may be transferred.
* AutomationOwner: sole authority to manage `YVault` execution.
* Strategy contracts have no special access rights; they are passive targets.

---

See [architecture.md](architecture.md) for how these interact, and [developer.md](developer.md) to customize or extend functionality.
