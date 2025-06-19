// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract LowRiskStrategy is IStrategy, Ownable , ReentrancyGuard {
    address public immutable USDC;
    address public immutable vault;
    address public activePool; // e.g., AaveStrategy contract

    event ActivePoolUpdated(address indexed newPool);

    constructor(address _usdc, address _vault) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_vault != address(0), "Invalid vault address");
        USDC = _usdc;
        vault = _vault;
    }

    function setActivePool(address _newPool) external onlyOwner {
        require(_newPool != address(0), "Invalid address");
        activePool = _newPool;
        emit ActivePoolUpdated(_newPool);
    }

    function execute(address user, uint256 amount) external override nonReentrant {
        require(msg.sender == vault, "Only vault can execute");
        require(activePool != address(0), "No active pool set");

        // At this point, Vault has already sent USDC to this contract
        //  Check that Vault has sent funds
        require(
            IERC20(USDC).balanceOf(address(this)) >= amount,
            "Not enough USDC"
        );

        // Approve the active pool to spend USDC and forward funds
        require(IERC20(USDC).approve(activePool, amount), "Approve failed");

        // Delegate execution to the current active pool (e.g., AaveStrategy)
        IStrategy(activePool).execute(user, amount);
    }
}
