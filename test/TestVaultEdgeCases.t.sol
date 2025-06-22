// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Contracts/Vaults/YVault.sol";
import "../src/Contracts/Strategies/MockERC20.sol";
import "../src/Contracts/Strategies/MockStrategy.sol";

contract YVaultEdgeCaseTest is Test {
    YVault vault;
    MockERC20 token;
    MockStrategy strategy;

    address user = address(0xABCD);
    address admin = address(0xDEAD);
    address chainlinkKeeper;

    function setUp() public {
        chainlinkKeeper = address(0xBEEF);
        token = new MockERC20("Mock Token", "MTK", 6);
        vault = new YVault(address(token), "TestVault", "TVLT", admin);
        vm.prank(admin);
        vault.setChainlinkKeeper(chainlinkKeeper);
        strategy = new MockStrategy(address(vault), address(token));

        token.mint(user, 1_000_000_000e6);
        vm.startPrank(user);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testLargeDeposit() public {
        vm.prank(user);
        vault.deposit(1_000_000_000e6); // 1 billion USDC
        assertEq(vault.v_totalAssets(), 1_000_000_000e6);
    }

    function testVerySmallDeposit() public {
        vm.prank(user);
        vault.deposit(1); // 1 wei of USDC (0.000001 USDC)
        assertEq(vault.v_totalAssets(), 1);
    }

    function testWithdrawWithUnderflow() public {
    uint256 depositAmount = 1e6; // 1 USDC

    // User deposits into the vault
    vm.prank(user);
    vault.deposit(depositAmount);

    // Simulate rogue strategy draining the vault by forcibly setting balance to zero
    deal(address(token), address(vault), 0);

    // Expect a revert when trying to withdraw — vault has no tokens
    vm.expectRevert(); // generic revert (you could match specific error if desired)
    vm.prank(user);
    vault.withdraw(depositAmount);
}



    function testDepositBeforeStrategyReportGain() public {
        vm.prank(user);
        vault.deposit(100e6);

        vm.prank(admin);
        vault.setStrategy(address(strategy));
        vm.prank(chainlinkKeeper);
        vault.allocateFunds(100e6);

        strategy.setFakeYield(10e6);
        token.mint(address(strategy), 10e6);

        // user2 deposits before yield reported
        address user2 = address(0xBEEF);
        token.mint(user2, 100e6);
        vm.startPrank(user2);
        token.approve(address(vault), type(uint256).max);
        vault.deposit(100e6);
        vm.stopPrank();

        vm.prank(admin);
        vault.reportFromStrategy();

        assertGt(vault.getPricePerShare(), 1e18);
    }

    // function testStrategyLossImpact() public {
    //     vm.prank(user);
    //     vault.deposit(100e6);

    //     vm.prank(admin);
    //     vault.setStrategy(address(strategy));
    //     vm.prank(admin);
    //     vault.allocateFunds(100e6);

    //     // Simulate 30 USDC loss
    //     strategy.setMockLossToReport(30e6);
    //     token.(address(strategy), 30e6);

    //     vm.prank(admin);
    //     vault.reportFromStrategy();

    //     // user tries to withdraw — should get less
    //     vm.prank(user);
    //     uint256 withdrawn = vault.withdraw(100e6);

    //     assertLt(withdrawn, 100e6);
    //     assertEq(vault.v_totalAssets(), 0);
    // }
}