// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStrategy} from "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAavePool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
}

contract AaveStrategy is IStrategy {
    address public immutable USDC;
    address public activePool;

    event ActivePoolUpdated(address indexed newPool);
    event MockSupplied(address indexed user, uint256 amount);

    constructor(address _usdc, address _initialPool) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_initialPool != address(0), "Invalid initial pool");
        USDC = _usdc;
        activePool = _initialPool;
        emit ActivePoolUpdated(_initialPool);
    }

    /// @notice Called by ElizaOS or EOA to update which mock pool is "active"
    function setActivePool(address _newPool) external {
        require(
            msg.sender == tx.origin || msg.sender == address(this),
            "Unauthorized"
        );
        require(_newPool != address(0), "Invalid pool");
        activePool = _newPool;
        emit ActivePoolUpdated(_newPool);
    }

    function execute(address user, uint256 amount) external override {
        require(activePool != address(0), "No active pool set");

        require(IERC20(USDC).balanceOf(address(this)) >= amount, "Not enough USDC");

        // Approve the pool to use the funds
        require(IERC20(USDC).approve(activePool, amount), "Approve failed");

        // Actually supply to the pool (mock or real)
        IAavePool(activePool).supply(USDC, amount, user, 0);

        emit MockSupplied(user, amount);
    }
}
