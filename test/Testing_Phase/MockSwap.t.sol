// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/Testing_Phase/Mocks/MockSwap.sol";
import "../../src/Testing_Phase/Mocks/MockUSDY.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/Interfaces/AggregatorV3Interface.sol";

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

contract MockSwapTest is Test {
    MockSwap public swap;
    MockUSDY public usdy;
    MockUSDC public usdc;
    MockPriceFeed public priceFeed;
    address public user = address(1);
    address public owner = address(this);

    function setUp() public {
        usdc = new MockUSDC();
        usdy = new MockUSDY();
        priceFeed = new MockPriceFeed(1e8, 8); // $1.00 price with 8 decimals
        
        // Deploy MockSwap with mocked price feed
        swap = new MockSwap(address(usdc), address(usdy), address(priceFeed));
        
        // Transfer some USDC to the swap contract for testing
        usdc.transfer(address(swap), 100_000 * 10**6); // 100k USDC
        
        // Transfer some USDY to the user for testing
        usdy.transfer(user, 100_000 * 10**18); // 100k USDY
    }

    function test_Constructor() public view {
        assertEq(address(swap.usdc()), address(usdc));
        assertEq(address(swap.usdy()), address(usdy));
    }

    function test_GetLatestPrice() public view {
        uint256 price = swap.getLatestPrice();
        assertTrue(price > 0, "Price should be greater than 0");
    }

    function test_SwapUSDYtoUSDC() public {
        uint256 usdyAmount = 1000 * 10**18; // 1000 USDY
        uint256 initialUserUSDC = usdc.balanceOf(user);
        uint256 initialUserUSDY = usdy.balanceOf(user);
        
        vm.startPrank(user);
        usdy.approve(address(swap), usdyAmount);
        uint256 usdcReceived = swap.swapUSDYtoUSDC(usdyAmount);
        vm.stopPrank();

        assertTrue(usdcReceived > 0, "Should receive USDC");
        assertEq(usdy.balanceOf(user), initialUserUSDY - usdyAmount, "USDY balance should decrease");
        assertEq(usdc.balanceOf(user), initialUserUSDC + usdcReceived, "USDC balance should increase");
    }

    function test_RevertWhen_SwapWithInsufficientUSDY() public {
        uint256 usdyAmount = 1_000_000 * 10**18; 
        vm.startPrank(user);
        usdy.approve(address(swap), usdyAmount);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        swap.swapUSDYtoUSDC(usdyAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_SwapWithZeroAmount() public {
        vm.startPrank(user);
        usdy.approve(address(swap), 0);
        vm.expectRevert("Amount must be greater than 0");
        swap.swapUSDYtoUSDC(0);
        vm.stopPrank();
    }
} 