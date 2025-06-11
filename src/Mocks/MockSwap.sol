// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MockSwap is ReentrancyGuard {
    mapping(address => uint256) public rates; // Exchange rates with 18 decimals
    address public owner;

    event Swap(
        address indexed fromToken,
        address indexed toToken,
        address indexed user,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Set exchange rate for a token pair
    function setRate(address token, uint256 rate) external onlyOwner {
        require(rate > 0, "Invalid rate");
        rates[token] = rate;
    }

    // Mock swap function
    function swap(
        address fromToken,
        address toToken,
        uint256 amountIn
    ) external nonReentrant returns (uint256 amountOut) {
        require(rates[fromToken] > 0 && rates[toToken] > 0, "Invalid tokens");
        
        // Calculate the amount out based on mock rates
        amountOut = (amountIn * rates[toToken]) / rates[fromToken];
        
        // Transfer tokens
        require(
            IERC20(fromToken).transferFrom(msg.sender, address(this), amountIn),
            "Transfer failed"
        );
        require(
            IERC20(toToken).transfer(msg.sender, amountOut),
            "Transfer failed"
        );

        emit Swap(fromToken, toToken, msg.sender, amountIn, amountOut);
        
        return amountOut;
    }

    // Function to withdraw tokens (for testing purposes)
    function withdrawToken(address token, uint256 amount) external onlyOwner {
        require(
            IERC20(token).transfer(owner, amount),
            "Withdrawal failed"
        );
    }
}