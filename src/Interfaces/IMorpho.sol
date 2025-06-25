// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IMorpho
/// @notice Interface for interacting with a Morpho lending/borrowing protocol
interface IMorpho {
    /// @notice Supplies assets into a given market for the specified receiver.
    /// @param market The address of the Morpho market (e.g., USDC lending pool)
    /// @param amount The amount of tokens to supply
    /// @param receiver The address that will receive the supply position
    function supply(address market, uint256 amount, address receiver) external;

    /// @notice Withdraws supplied assets from a market for the specified receiver.
    /// @param market The address of the Morpho market to withdraw from
    /// @param amount The amount of tokens to withdraw
    /// @param receiver The address that will receive the withdrawn tokens
    function withdraw(
        address market,
        uint256 amount,
        address receiver
    ) external;

    /// @notice Returns the balance of supplied assets in a given market for a specific account.
    /// @param market The address of the Morpho market to query
    /// @param account The address of the user whose balance is being queried
    /// @return The amount of underlying asset supplied by the account
    function balanceOf(
        address market,
        address account
    ) external view returns (uint256);
}
