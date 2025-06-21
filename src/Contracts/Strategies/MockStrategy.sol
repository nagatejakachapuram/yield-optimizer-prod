// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IStrategy} from "../../Interfaces/IStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockStrategy is IStrategy {
    using SafeERC20 for IERC20;

    address public vault;
    IERC20 public immutable usdc;

    uint256 public totalUSDC;
    uint256 public fakeYield; // Simulates gain
    bool public shouldRevert; // Simulates failure

    constructor(address _vault, address _usdc) {
        vault = _vault;
        usdc = IERC20(_usdc);
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Not vault");
        _;
    }

    function allocate(address, uint256 amount) external override onlyVault {
        require(!shouldRevert, "Simulated failure");
        usdc.safeTransferFrom(vault, address(this), amount);
        totalUSDC += amount;
    }

    function withdraw(uint256 amountNeeded) external override onlyVault returns (uint256 loss) {
        require(!shouldRevert, "Simulated failure");
        uint256 toSend = totalUSDC + fakeYield;
        totalUSDC = 0;
        fakeYield = 0;
        usdc.safeTransfer(vault, toSend);
        return amountNeeded > toSend ? amountNeeded - toSend : 0;
    }

    function report() external view override onlyVault returns (uint256 gain, uint256 loss, uint256 debtPayment) {
        gain = fakeYield;
        loss = 0;
        debtPayment = 0;
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return totalUSDC + fakeYield;
    }

    // Test helpers
    function setFakeYield(uint256 amount) external {
        fakeYield = amount;
    }

    function setShouldRevert(bool val) external {
        shouldRevert = val;
    }
}
