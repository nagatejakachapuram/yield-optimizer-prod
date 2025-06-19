// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPendleRouter {
    function depositMarket(address market, uint256 amount, address receiver) external;
}

contract PendleStrategy is IStrategy {
    address public immutable USDC;
    IPendleRouter public immutable pendleRouter;
    address public activeMarket;

    event ActiveMarketUpdated(address indexed newMarket);

    constructor(address _usdc, address _pendleRouter) {
        USDC = _usdc;
        pendleRouter = IPendleRouter(_pendleRouter);
    }

    function setActiveMarket(address _newMarket) external {
        require(msg.sender == address(this) || msg.sender == tx.origin, "Unauthorized");
        require(_newMarket != address(0), "Invalid market");
        activeMarket = _newMarket;
        emit ActiveMarketUpdated(_newMarket);
    }

    function execute(address user, uint256 amount) external override {
        require(activeMarket != address(0), "No active market set");
        IERC20(USDC).transferFrom(user, address(this), amount);
        IERC20(USDC).approve(address(pendleRouter), amount);
        pendleRouter.depositMarket(activeMarket, amount, address(this));
    }
}
