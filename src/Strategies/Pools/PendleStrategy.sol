// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPendleMarket {
    function depositMarket(
        address token,
        uint256 amount,
        address user
    ) external;
}

contract PendleStrategy is IStrategy {
    address public immutable USDC;
    address public activeMarket;

    event ActiveMarketUpdated(address indexed newMarket);
    event MockDeposited(address indexed user, uint256 amount);

    constructor(address _usdc, address _initialMarket) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_initialMarket != address(0), "Invalid initial market");
        USDC = _usdc;
        activeMarket = _initialMarket;
        emit ActiveMarketUpdated(_initialMarket);
    }

    /// @notice Simulates setting the best Pendle market from AI
    function setActiveMarket(address _newMarket) external {
        require(
            msg.sender == tx.origin || msg.sender == address(this),
            "Unauthorized"
        );
        require(_newMarket != address(0), "Invalid market");
        activeMarket = _newMarket;
        emit ActiveMarketUpdated(_newMarket);
    }

    /// @notice Simulates depositing USDC into a Pendle pool
    function execute(address user, uint256 amount) external override {
        require(activeMarket != address(0), "No active market set");

        require(IERC20(USDC).balanceOf(address(this)) >= amount, "Not enough USDC");

        // Approve the market to use the USDC
        require(IERC20(USDC).approve(activeMarket, amount), "Approve failed");

        // Forward deposit to the mock Pendle market (simulate actual behavior)
        IPendleMarket(activeMarket).depositMarket(USDC, amount, user);

        emit MockDeposited(user, amount);
    }
}
