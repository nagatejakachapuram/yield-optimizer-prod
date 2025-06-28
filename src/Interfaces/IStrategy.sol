// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/// @title IStrategy
/// @notice Interface for strategy contracts used by yield-optimizing vaults
interface IStrategy {
    /// @notice Allocate funds from the vault to this strategy
    /// @param vault The address of the vault calling the strategy
    /// @param amount The amount of assets to allocate
    function allocate(address vault, uint256 amount) external;

    /// @notice Estimate the total assets managed by this strategy
    /// @dev This may include both idle and deployed capital
    /// @return The total estimated value of assets managed by the strategy
    function estimatedTotalAssets() external view returns (uint256);

    /// @notice Withdraw a specific amount of assets back to the vault
    /// @param amount The amount of assets to withdraw
    /// @return loss If the strategy cannot return the full amount, returns the shortfall
    function withdraw(uint256 amount) external returns (uint256 loss);

    /// @notice Report gains or losses and optionally return funds to the vault
    /// @dev Called by the vault to synchronize accounting and performance metrics
    /// @return gain Amount of profit realized since last report
    /// @return loss Amount of loss realized since last report
    /// @return debtPayment Amount of capital returned to the vault during the report
    function report() external returns (uint256 gain, uint256 loss, uint256 debtPayment);

    // function estimatedAPY() external view returns (uint256);
}
