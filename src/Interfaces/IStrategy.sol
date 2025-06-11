// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IStrategy {
    function execute(address user, uint256 amount) external;
    
}