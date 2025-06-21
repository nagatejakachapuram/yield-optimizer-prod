// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IYVault {
    // Core Vault Operations
    function deposit(uint256 amount) external returns (uint256 shares);
    function withdraw(uint256 shares) external returns (uint256 amount);
    function allocateFunds(uint256 amount) external;

    // Strategy Management
    function setStrategy(address strategy) external;
    function reportFromStrategy() external;

    // Ownership
    function transferVaultOwnership(address newOwner) external;

    // View Functions
    function getPricePerShare() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function verifyReserves() external view returns (bool isConsistent, uint256 actualAssets, uint256 expectedAssets);
    function asset() external view returns (address);
    function vaultOwnerSafe() external view returns (address);
    function currentStrategy() external view returns (address);
    function balanceOf(address user) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    // Events
    event VaultDeposit(address indexed user, uint256 assets, uint256 shares);
    event VaultWithdraw(address indexed user, uint256 assets, uint256 shares);
    event VaultStrategyReported(uint256 gain, uint256 loss, uint256 totalAssets);
    event VaultStrategySet(address strategy);
    event VaultOwnerTransferred(address newOwner);
    event FundsAllocated(uint256 amount);
}
