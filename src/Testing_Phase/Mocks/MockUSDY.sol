// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSDY is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10 ** 18; // 1 million USDY
    uint256 public currentYield = 500; // 5.00% APY (stored with 2 decimals)

    constructor() ERC20("Mock USDY", "USDY") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // Mock function to simulate yield changes
    function setCurrentYield(uint256 newYield) external onlyOwner {
        require(newYield <= 10_000, "Yield cannot exceed 100%");
        currentYield = newYield;
    }

    // Mock function to mint new tokens (simulating yield distribution)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Mock function to get current APY (returns yield with 2 decimals)
    function getCurrentYield() external view returns (uint256) {
        return currentYield;
    }
}
