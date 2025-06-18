// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStrategy} from "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

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
    IAavePool public immutable aavePool;

    constructor(address _usdc, address _aavePool) {
        USDC = _usdc;
        aavePool = IAavePool(_aavePool);
    }

    function execute(address user, uint256 amount) external override {
        // Vault or LowRiskStrategy must send funds to this adapter
        // So we don't pull from user, we just deposit what's already here
        console.log("user: ", user);
        IERC20(USDC).approve(address(aavePool), amount);
        aavePool.supply(USDC, amount, address(this), 0);
    }
}
