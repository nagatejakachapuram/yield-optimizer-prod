// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStrategy} from "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
}

contract AaveStrategy is IStrategy {
    address public immutable USDC;

    address public activePool;

    event ActivePoolUpdated(address indexed newPool);

    constructor(address _usdc, address _initialPool) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_initialPool != address(0), "Invalid initial pool");
        USDC = _usdc;
        activePool = _initialPool;
        emit ActivePoolUpdated(_initialPool);
    }

    /// @notice Updates the current Aave pool used for supplying USDC
    /// Can be called by AI agent (EOA) or the contract itself
    function setActivePool(address _newPool) external {
        require(msg.sender == tx.origin || msg.sender == address(this), "Unauthorized");
        require(_newPool != address(0), "Invalid pool");
        activePool = _newPool;
        emit ActivePoolUpdated(_newPool);
    }

    /// @notice Called by the Vault to execute the strategy
    /// Assumes USDC has already been transferred to this strategy
    function execute(address user, uint256 amount) external override {
        require(activePool != address(0), "No active pool set");
        console.log("user:", user);
        console.log("amount:", amount);

        // Approve USDC to be used by the selected Aave pool
        IERC20(USDC).approve(activePool, amount);

        // Supply USDC to Aave
        IAavePool(activePool).supply(USDC, amount, address(this), 0);
    }
}
