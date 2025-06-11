// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;


interface IVault {
    function allocateFunds(address user, uint256 amount, address strategy) external;
}
