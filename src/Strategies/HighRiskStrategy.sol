// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract HighRiskStrategy is IStrategy, Ownable {
    address public immutable usdc;
    address public activePool;

    event ActivePoolUpdated(address indexed newPool);

    constructor(address _usdc) {
        require(_usdc != address(0), "USDC address cannot be zero");
        usdc = _usdc;
    }

    function setActivePool(address newPool) external onlyOwner {
        require(newPool != address(0), "Invalid address");
        activePool = newPool;
        emit ActivePoolUpdated(newPool);
    }

    function execute(address user, uint256 amount) external override {
        require(user == msg.sender, "Only user can execute");
        require(activePool != address(0), "No active pool set");

        require(IERC20(usdc).transferFrom(msg.sender, address(this), amount), "Transfer failed");
        require(IERC20(usdc).approve(activePool, amount), "Approve failed");

        IStrategy(activePool).execute(msg.sender, amount);
    }
}
