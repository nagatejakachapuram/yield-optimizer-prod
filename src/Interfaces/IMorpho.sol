// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMorpho {
    /// @notice Supplies assets into a given market for the specified receiver.
    /// @param market Address of the Morpho market (e.g., USDC market)
    /// @param amount Amount of tokens to supply
    /// @param receiver Who receives the supply position
    function supply(address market, uint256 amount, address receiver) external;

    /// @notice Withdraws supplied assets from a market for the specified receiver.
    /// @param market Address of the Morpho market
    /// @param amount Amount to withdraw
    /// @param receiver Who receives the withdrawn assets
    function withdraw(
        address market,
        uint256 amount,
        address receiver
    ) external;

    /// @notice Returns the balance of supplied assets in the given market for the account.
    /// @param market Address of the Morpho market
    /// @param account Address whose balance to check
    /// @return Amount of underlying asset supplied
    function balanceOf(
        address market,
        address account
    ) external view returns (uint256);
}
