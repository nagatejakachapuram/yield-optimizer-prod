// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IMockSwap {
    function swapUSDYtoUSDC(uint256 amount) external returns (uint256);
    function getUSDCPrice() external view returns (uint256);
}