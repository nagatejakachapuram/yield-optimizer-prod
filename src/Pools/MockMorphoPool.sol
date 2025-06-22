// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Interfaces/IMorpho.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockMorpho is IMorpho {
    error ZeroAmount();
    error NoDeposit();
    error NoBalance();
    error NoYieldAvailable();

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTime;
    mapping(address => uint256) public claimedYield;

    address public usdc;
    uint256 public apyBasisPoints;

    constructor(address _usdc, uint256 _apyBasisPoints) {
        usdc = _usdc;
        apyBasisPoints = _apyBasisPoints;
    }

    function supply(address, uint256 amount, address onBehalf) external override {
        if (amount == 0) revert ZeroAmount();
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);
        balances[onBehalf] += amount;
        depositTime[onBehalf] = block.timestamp;
    }

    function withdraw(address, uint256 amount, address to) external override {
        if (balances[msg.sender] < amount) revert NoBalance();
        balances[msg.sender] -= amount;
        IERC20(usdc).transfer(to, amount);
    }

    function balanceOf(address, address user) external view override returns (uint256) {
        uint256 principal = balances[user];
        if (principal == 0) return 0;

        uint256 timeHeld = block.timestamp - depositTime[user];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) / (365 days * 10000);
        return principal + totalYield;
    }

    function claimYield() external {
        uint256 principal = balances[msg.sender];
        if (principal == 0) revert NoDeposit();

        uint256 timeHeld = block.timestamp - depositTime[msg.sender];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) / (365 days * 10000);
        uint256 yieldToClaim = totalYield - claimedYield[msg.sender];

        if (yieldToClaim == 0) revert NoYieldAvailable();

        claimedYield[msg.sender] += yieldToClaim;
        IERC20(usdc).transfer(msg.sender, yieldToClaim);
    }
}
