// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVault {
    // Core Deposit & Withdrawal
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function withdrawForUser(address _user, uint256 amount) external;

    // Strategy Management
    function setApprovedStrategy(address strategy, bool approved) external;
    function allocateFunds(address user, uint256 amount, address strategy) external;

    // USDY Swap
    function swapUSDYtoUSDC(uint256 amount) external;

    // Admin Controls (Pausable & Ownership)
    function pause() external;
    function unpause() external;
    function transferAdminOwnership(address newAdmin) external;
    function acceptAdminOwnership() external;
    function recoverERC20(address tokenAddress, uint256 amount) external;

    // View Getters
    function userDeposits(address) external view returns (uint256);
    function totalValueLocked() external view returns (uint256);
    function approvedStrategies(address) external view returns (bool);
    function usdc() external view returns (address);
    function usdy() external view returns (address);
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function mockSwap() external view returns (address);

    // Events
    event DepositSuccessful(address indexed user, uint256 amount);
    event WithdrawalSuccessful(address indexed user, uint256 amount);
    event StrategyApprovalUpdated(address indexed strategy, bool approved);
    event FundsAllocated(address indexed user, address indexed strategy, uint256 amount);
    event AdminTransferProposed(address indexed newAdmin);
    event AdminTransferAccepted(address indexed newAdmin);
    event TokensRecovered(address indexed tokenAddress, address indexed recipient, uint256 amount); // Note the amount type, should be uint256 based on your Vault contract
}