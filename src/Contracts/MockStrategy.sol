// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Interfaces/IStrategy.sol";

contract MockStrategy is IStrategy {
    address public immutable mockUSDC;

    constructor(address _mockUSDC) {
        mockUSDC = _mockUSDC;
    }

    function execute(address user, uint256 amount) external override {
        // In a real strategy, this would interact with other DeFi protocols
        // For a mock, we just simulate success.
        // You might want to add some logging here if you want to see it called.
        // No explicit return needed as IStrategy does not have one.
    }

    // You might need a way to get funds into this mock strategy for more advanced testing.
    // For now, we'll assume the Vault transfers funds to it directly.
} 