// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/mocks/MockUSDY.sol";
import "../src/mocks/MockSwap.sol";
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

contract MockUSDYIntegrationTest is Test {
    MockUSDY public usdy;
    MockSwap public swap;
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
    }

    function test_YieldChangesAffectSwap() public {
        // Initial yield is 5%
        uint256 initialYield = usdy.currentYield();
        assertEq(initialYield, 500);

        // Change yield to 7.5%
        usdy.setCurrentYield(750);
        assertEq(usdy.currentYield(), 750);

        // Transfer USDY to user and perform swap
        usdy.transfer(user1, 1000 * 10**18);
        vm.startPrank(user1);
        usdy.approve(address(swap), 1000 * 10**18);
        uint256 usdcReceived = swap.swapUSDYtoUSDC(1000 * 10**18);
        vm.stopPrank();

        assertTrue(usdcReceived > 0, "Swap should succeed with new yield");
    }

    function test_MintAndSwap() public {
        // Mint new USDY tokens
        uint256 mintAmount = 1000 * 10**18;
        usdy.mint(user1, mintAmount);
        assertEq(usdy.balanceOf(user1), mintAmount);

        // Perform swap with minted tokens
        vm.startPrank(user1);
        usdy.approve(address(swap), mintAmount);
        uint256 usdcReceived = swap.swapUSDYtoUSDC(mintAmount);
        vm.stopPrank();

        assertTrue(usdcReceived > 0, "Swap should succeed with minted tokens");
        assertEq(usdy.balanceOf(user1), 0, "All minted tokens should be swapped");
    }

    function test_MultipleYieldChanges() public {
        uint256[] memory yields = new uint256[](3);
        yields[0] = 500;  // 5%
        yields[1] = 750;  // 7.5%
        yields[2] = 1000; // 10%

        for (uint i = 0; i < yields.length; i++) {
            usdy.setCurrentYield(yields[i]);
            assertEq(usdy.currentYield(), yields[i], "Yield should be updated correctly");
            
            // Verify getCurrentYield returns correct value
            assertEq(usdy.getCurrentYield(), yields[i], "getCurrentYield should match set yield");
        }
    }

    function test_YieldChangesWithMultipleUsers() public {
        // Distribute USDY to users
        usdy.transfer(user1, 1000 * 10**18);
        usdy.transfer(user2, 1000 * 10**18);

        // Change yield and verify both users can still interact
        usdy.setCurrentYield(750);
        
        vm.startPrank(user1);
        usdy.approve(address(swap), 500 * 10**18);
        uint256 usdcReceived1 = swap.swapUSDYtoUSDC(500 * 10**18);
        vm.stopPrank();

        vm.startPrank(user2);
        usdy.approve(address(swap), 500 * 10**18);
        uint256 usdcReceived2 = swap.swapUSDYtoUSDC(500 * 10**18);
        vm.stopPrank();

        assertTrue(usdcReceived1 > 0 && usdcReceived2 > 0, "Both users should be able to swap");
    }
} 