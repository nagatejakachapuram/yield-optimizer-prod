    // SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

interface IStrategy {
    function execute(address user, uint256 amount) external;
}
