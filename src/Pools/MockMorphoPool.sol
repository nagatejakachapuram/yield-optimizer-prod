// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Interfaces/IMorpho.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockMorpho is IMorpho {
    mapping(address => uint256) public balances;
    address public usdc;

    constructor(address _usdc) {
        usdc = _usdc;
    }

    function supply(address, uint256 amount, address onBehalf) external override {
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);
        balances[onBehalf] += amount;
    }

    function withdraw(address, uint256 amount, address to) external override {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        IERC20(usdc).transfer(to, amount);
    }

    function balanceOf(address, address user) external view override returns (uint256) {
        return balances[user];
    }
}
