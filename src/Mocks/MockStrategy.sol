// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Interfaces/IStrategy.sol";

contract MockStrategy is IStrategy {
    address public immutable mockUSDC;

    constructor(address _mockUSDC) {
        mockUSDC = _mockUSDC;
    }

    function execute(address user, uint256 amount) external override {
    }
} 