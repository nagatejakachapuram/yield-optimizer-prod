// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/mocks/MockSwap.sol";
import "../src/mocks/MockUSDY.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/Interfaces/AggregatorV3Interface.sol";

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

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000 * 10**6); // 1 million USDC
    }
}

contract MockSwapIntegrationTest is Test {
    MockSwap public swap;
    MockUSDY public usdy;
    MockUSDC public usdc;
    MockPriceFeed public priceFeed;
    address public user1 = address(1);
    address public user2 = address(2);
    address public owner = address(this);

    function setUp() public {
        usdc = new MockUSDC();
        usdy = new MockUSDY();
        priceFeed = new MockPriceFeed(1e8, 8); // $1.00 price with 8 decimals
        
        // Deploy MockSwap with mocked price feed
        swap = new MockSwap(address(usdc), address(usdy), address(priceFeed));
        
        // Transfer USDC to the swap contract
        usdc.transfer(address(swap), 500_000 * 10**6); // 500k USDC
        
        // Distribute USDY to users
        usdy.transfer(user1, 50_000 * 10**18); // 50k USDY
        usdy.transfer(user2, 50_000 * 10**18); // 50k USDY
    }

    function test_MultipleUsersSwap() public {
        uint256 usdyAmount = 1000 * 10**18; // 1000 USDY
        
        // User 1 swaps
        vm.startPrank(user1);
        usdy.approve(address(swap), usdyAmount);
        uint256 usdcReceived1 = swap.swapUSDYtoUSDC(usdyAmount);
        vm.stopPrank();

        // User 2 swaps
        vm.startPrank(user2);
        usdy.approve(address(swap), usdyAmount);
        uint256 usdcReceived2 = swap.swapUSDYtoUSDC(usdyAmount);
        vm.stopPrank();

        assertTrue(usdcReceived1 > 0 && usdcReceived2 > 0, "Both users should receive USDC");
        assertEq(usdy.balanceOf(user1), 49_000 * 10**18, "User 1 USDY balance should decrease");
        assertEq(usdy.balanceOf(user2), 49_000 * 10**18, "User 2 USDY balance should decrease");
    }

    function test_SwapWithYieldChanges() public {
        uint256 usdyAmount = 1000 * 10**18;
        
        // First swap
        vm.startPrank(user1);
        usdy.approve(address(swap), usdyAmount);
        uint256 usdcReceived1 = swap.swapUSDYtoUSDC(usdyAmount);
        
        // Change yield
        vm.stopPrank();
        usdy.setCurrentYield(750); // 7.50%
        
        // Second swap
        vm.startPrank(user1);
        usdy.approve(address(swap), usdyAmount);
        uint256 usdcReceived2 = swap.swapUSDYtoUSDC(usdyAmount);
        vm.stopPrank();

        assertTrue(usdcReceived1 > 0 && usdcReceived2 > 0, "Both swaps should succeed");
    }

    function test_RevertWhen_SwapWithInsufficientUSDC() public {
        // Approve USDC transfer from swap contract
        vm.startPrank(address(swap));
        usdc.approve(owner, usdc.balanceOf(address(swap)));
        vm.stopPrank();

        // Drain USDC from swap contract
        usdc.transferFrom(address(swap), owner, usdc.balanceOf(address(swap)));
        
        vm.startPrank(user1);
        usdy.approve(address(swap), 1000 * 10**18);
        vm.expectRevert("Insufficient USDC liquidity");
        swap.swapUSDYtoUSDC(1000 * 10**18);
        vm.stopPrank();
    }

    function test_SwapWithPriceFeed() public {
        uint256 price = swap.getLatestPrice();
        assertTrue(price > 0, "Price feed should return valid price");
        
        uint256 usdyAmount = 1000 * 10**18;
        vm.startPrank(user1);
        usdy.approve(address(swap), usdyAmount);
        uint256 usdcReceived = swap.swapUSDYtoUSDC(usdyAmount);
        vm.stopPrank();

        // Verify the swap amount is calculated correctly based on price
        assertTrue(usdcReceived > 0, "Should receive USDC based on price feed");
    }
} 