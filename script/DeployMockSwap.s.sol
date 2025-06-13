// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/mocks/MockSwap.sol";
import "../src/mocks/MockUSDY.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Interfaces/AggregatorV3Interface.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockPriceFeed is AggregatorV3Interface {
    int256 private price;
    uint8 private decimals_;

    constructor(int256 _price, uint8 _decimals) {
        price = _price;
        decimals_ = _decimals;
    }

    function decimals() external view override returns (uint8) {
        return decimals_;
    }

    function description() external pure override returns (string memory) {
        return "Mock Price Feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert("Not implemented");
    }

    function latestRoundData() external view override returns (uint80, int256, uint256, uint256, uint80) {
        return (0, price, 0, block.timestamp, 0);
    }
}

contract DeployMockSwap is Script {
    function run() public returns (MockSwap) {
        vm.startBroadcast();

        // Deploy MockUSDC if not already deployed
        MockUSDC usdc = new MockUSDC();

        usdc.mint(msg.sender, 1_000_000 * 10**6);
        
        // Deploy MockUSDY if not already deployed
        MockUSDY usdy = new MockUSDY();
        
        // Deploy MockPriceFeed
        MockPriceFeed priceFeed = new MockPriceFeed(1e8, 8); // $1.00 price with 8 decimals
        
        // Deploy MockSwap
        MockSwap swap = new MockSwap(address(usdc), address(usdy), address(priceFeed));
        
        // Transfer initial USDC to swap contract
        usdc.transfer(address(swap), 500_000 * 10**6); // 500k USDC

        vm.stopBroadcast();
        return swap;
    }
} 
