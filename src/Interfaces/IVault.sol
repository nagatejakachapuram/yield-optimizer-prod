// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IYVault
/// @notice Interface for a Yearn-style yield vault with strategy allocation and share-based accounting
interface IYVault {
    // ----------------------------------
    // Core Vault Operations
    // ----------------------------------

    /// @notice Deposit a specific amount of underlying asset into the vault
    /// @param amount The amount of the underlying asset to deposit
    /// @return shares The number of vault shares minted to the depositor
    function deposit(uint256 amount) external returns (uint256 shares);

    /// @notice Withdraw a specific number of shares from the vault
    /// @param shares The number of shares to redeem
    /// @return amount The amount of underlying asset returned to the user
    function withdraw(uint256 shares) external returns (uint256 amount);

    /// @notice Allocate funds from the vault to the current strategy
    /// @param amount The amount of assets to allocate
    function allocateFunds(uint256 amount) external;

    // ----------------------------------
    // Strategy Management
    // ----------------------------------

    /// @notice Sets the active strategy for the vault
    /// @param strategy The address of the new strategy contract
    function setStrategy(address strategy) external;

    /// @notice Fetch a report from the active strategy, updating vault accounting
    function reportFromStrategy() external;

    // ----------------------------------
    // Ownership
    // ----------------------------------

    /// @notice Transfers ownership of the vault to a new owner
    /// @param newOwner The address to which ownership will be transferred
    function transferVaultOwnership(address newOwner) external;

    // ----------------------------------
    // View Functions
    // ----------------------------------

    /// @notice Returns the current price per share
    /// @dev Typically calculated as totalAssets / totalSupply
    /// @return The value of one share in terms of the underlying asset
    function getPricePerShare() external view returns (uint256);

    /// @notice Returns the total amount of underlying assets managed by the vault
    function totalAssets() external view returns (uint256);

    /// @notice Returns the total number of vault shares in existence
    function totalSupply() external view returns (uint256);

    /// @notice Verifies whether the vault’s on-chain reserves match accounting expectations
    /// @return isConsistent True if actual and expected reserves match within margin
    /// @return actualAssets Assets currently held by the vault + strategy
    /// @return expectedAssets Assets calculated based on shares and price
    function verifyReserves() external view returns (
        bool isConsistent,
        uint256 actualAssets,
        uint256 expectedAssets
    );

    /// @notice Returns the address of the underlying asset used by the vault (e.g., USDC)
    function asset() external view returns (address);

    /// @notice Returns the current vault owner (authorized for admin operations)
    function vaultOwnerSafe() external view returns (address);

    /// @notice Returns the address of the active strategy
    function currentStrategy() external view returns (address);

    /// @notice Returns the number of vault shares held by a specific user
    /// @param user The user address to check
    function balanceOf(address user) external view returns (uint256);

    /// @notice Returns the allowance for a given spender from a specific owner
    /// @param owner The address of the token owner
    /// @param spender The address authorized to spend
    function allowance(address owner, address spender) external view returns (uint256);

    // ----------------------------------
    // Events
    // ----------------------------------

    /// @notice Emitted when a user deposits assets into the vault
    /// @param user The user who deposited
    /// @param assets The amount of underlying assets deposited
    /// @param shares The number of vault shares minted
    event VaultDeposit(address indexed user, uint256 assets, uint256 shares);

    /// @notice Emitted when a user withdraws assets from the vault
    /// @param user The user who withdrew
    /// @param assets The amount of underlying assets returned
    /// @param shares The number of shares redeemed
    event VaultWithdraw(address indexed user, uint256 assets, uint256 shares);

    /// @notice Emitted after a strategy reports its gain/loss
    /// @param gain The gain reported by the strategy
    /// @param loss The loss reported by the strategy
    /// @param totalAssets The new total asset balance of the vault
    event VaultStrategyReported(uint256 gain, uint256 loss, uint256 totalAssets);

    /// @notice Emitted when a new strategy is set
    /// @param strategy The address of the newly set strategy
    event VaultStrategySet(address strategy);

    /// @notice Emitted when ownership of the vault is transferred
    /// @param newOwner The new owner address
    event VaultOwnerTransferred(address newOwner);

    /// @notice Emitted when funds are allocated to the strategy
    /// @param amount The amount allocated
    event FundsAllocated(uint256 amount);
}
