// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../../src/Testing_Phase/Mocks/MockUSDY.sol";

contract MockUSDYTest is Test {
    MockUSDY public usdy;
    address public user = address(1);
    address public owner = address(this);

    function setUp() public {
        usdy = new MockUSDY();
    }

    function test_Constructor() public view {
        assertEq(usdy.name(), "Mock USDY");
        assertEq(usdy.symbol(), "USDY");
        assertEq(usdy.totalSupply(), 1_000_000 * 10 ** 18);
        assertEq(usdy.balanceOf(owner), 1_000_000 * 10 ** 18);
        assertEq(usdy.currentYield(), 500); // 5.00%
    }

    function test_SetCurrentYield() public {
        uint256 newYield = 750; // 7.50%
        usdy.setCurrentYield(newYield);
        assertEq(usdy.currentYield(), newYield);
    }

    function test_RevertWhen_SetCurrentYieldTooHigh() public {
        vm.expectRevert("Yield cannot exceed 100%");
        usdy.setCurrentYield(10_001);
    }

    function test_Mint() public {
        uint256 amount = 1000 * 10 ** 18;
        uint256 initialBalance = usdy.balanceOf(user);

        usdy.mint(user, amount);

        assertEq(usdy.balanceOf(user), initialBalance + amount);
        assertEq(usdy.totalSupply(), 1_000_000 * 10 ** 18 + amount);
    }

    function test_RevertWhen_MintNotOwner() public {
        vm.startPrank(user);
        vm.expectRevert("Ownable: caller is not the owner");
        usdy.mint(user, 1000 * 10 ** 18);
        vm.stopPrank();
    }

    function test_GetCurrentYield() public view {
        assertEq(usdy.getCurrentYield(), 500); // 5.00%
    }
}
