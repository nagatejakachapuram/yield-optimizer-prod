// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockDYIOracle {
    int256 public latestYield;

    constructor(int256 _initialYield) {
        latestYield = _initialYield;
    }

    function setYield(int256 _newYield) external {
        latestYield = _newYield;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, latestYield, block.timestamp, block.timestamp, 0);
    }
}
