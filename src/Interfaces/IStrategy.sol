// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IStrategy {
    function allocate(address vault, uint256 amount) external;
    function estimatedTotalAssets() external view returns (uint256);
    function withdraw(uint256 amount) external returns (uint256 loss);
    function report() external returns (uint256 gain, uint256 loss, uint256 debtPayment);
}
