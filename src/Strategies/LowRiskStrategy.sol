// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Interfaces/IStrategy.sol";

contract LowRiskStrategy is IStrategy {
    event StrategyExecuted(address user, uint256 amount);

    function execute(address user, uint256 amount) external override {
        emit StrategyExecuted(user, amount); // For debugging
    }
}
