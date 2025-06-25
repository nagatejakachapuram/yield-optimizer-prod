// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Contracts/Vaults/YVault.sol";
import "../src/Contracts/Strategies/MockERC20.sol";
import "../src/Contracts/Strategies/MockStrategy.sol";

contract YVaultTest is Test {
    YVault vault;
    MockERC20 token;
    MockStrategy strategy;

    address user = address(0xABCD);
    address admin = address(0xDEAD);
    address chainlinkKeeper;

    function setUp() public {
        chainlinkKeeper = address(0xBEEF);
        token = new MockERC20("Mock Token", "MTK", 6); // like USDC
        vault = new YVault(address(token), "TestVault", "TVLT", admin);
        vm.prank(admin);
        vault.setChainlinkKeeper(chainlinkKeeper);
        strategy = new MockStrategy(address(vault), address(token));
        chainlinkKeeper = address(0xBEEF); // mock keeper address

        // Mint and approve tokens for user
        token.mint(user, 1_000_000e6);
        vm.startPrank(user);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialSetup() public view {
        assertEq(address(vault.asset()), address(token));
        assertEq(vault.v_name(), "TestVault");
        assertEq(vault.v_symbol(), "TVLT");
    }

    function testDepositAndWithdraw() public {
        uint256 amount = 1000e6;

        vm.prank(user);
        uint256 shares = vault.deposit(amount);
        assertEq(vault.balanceOf(user), shares);
        assertEq(token.balanceOf(address(vault)), amount);

        vm.prank(user);
        uint256 withdrawn = vault.withdraw(shares);
        assertEq(token.balanceOf(user), 1_000_000e6);
        assertEq(withdrawn, amount);
    }

    function testDepositZeroReverts() public {
        vm.expectRevert(YVault.ZeroAmount.selector);
        vm.prank(user);
        vault.deposit(0);
    }

    function testWithdrawZeroReverts() public {
        vm.expectRevert(YVault.ZeroAmount.selector);
        vm.prank(user);
        vault.withdraw(0);
    }

    function testWithdrawExcessSharesReverts() public {
        vm.expectRevert(YVault.InsufficientShares.selector);
        vm.prank(user);
        vault.withdraw(1000);
    }

    function testSetStrategyAndAllocate() public {
        uint256 depositAmount = 1000e6;

        vm.prank(user);
        vault.deposit(depositAmount);

        vm.prank(admin);
        vault.setStrategy(address(strategy));
        assertEq(address(vault.currentStrategy()), address(strategy));

        vm.prank(chainlinkKeeper);
        vault.allocateFunds(500e6);

        assertEq(token.balanceOf(address(strategy)), 500e6);
    }

    function testAllocateWithoutStrategyReverts() public {
        vm.prank(chainlinkKeeper);
        vm.expectRevert(YVault.InsufficientVaultBalance.selector);
        vault.allocateFunds(1e6);
    }

    function testAllocateMoreThanVaultBalanceReverts() public {
        vm.prank(admin);
        vault.setStrategy(address(strategy));

        vm.prank(chainlinkKeeper);
        vm.expectRevert(YVault.InsufficientVaultBalance.selector);
        vault.allocateFunds(1e6);
    }

    function testReportFromStrategy() public {
        uint256 depositAmount = 1000e6;

        vm.prank(user);
        vault.deposit(depositAmount);

        vm.prank(admin);
        vault.setStrategy(address(strategy));

        // Simulate first gain
        strategy.setFakeYield(100e6);
        token.mint(address(strategy), 100e6);

        vm.prank(admin);
        vault.reportFromStrategy();

        // Simulate second gain
        strategy.setFakeYield(50e6);
        token.mint(address(strategy), 50e6);

        vm.prank(admin);
        vault.reportFromStrategy();
    }

    function testReportWithNoStrategyReverts() public {
        vm.expectRevert(YVault.StrategyNotSet.selector);
        vm.prank(admin);
        vault.reportFromStrategy();
    }

    function testTransferOwnership() public {
        address newOwner = address(0xBEEF);
        vm.prank(admin);
        vault.transferVaultOwnership(newOwner);
        assertEq(vault.vaultOwnerSafe(), newOwner);
    }

    function testUnauthorizedOwnershipTransferReverts() public {
        vm.expectRevert(YVault.NotVaultOwner.selector);
        vault.transferVaultOwnership(user);
    }

    function testUnauthorizedSetStrategyReverts() public {
        vm.expectRevert(YVault.NotVaultOwner.selector);
        vm.prank(user);
        vault.setStrategy(address(strategy));
    }

    function testPricePerShareAccuracy() public {
        vm.prank(user);
        vault.deposit(1000e6);
        assertEq(vault.getPricePerShare(), 1e18);
    }

    function testZeroTotalSharesConversion() public view {
        assertEq(vault.getPricePerShare(), 1e18);
        assertEq(vault.v_totalShares(), 0);
    }

    function testStrategyWithdrawsPartialOnInsufficientBalance() public {
        token.mint(address(strategy), 250e6);

        vm.prank(user);
        vault.deposit(500e6);

        vm.prank(admin);
        vault.setStrategy(address(strategy));

        vm.prank(chainlinkKeeper);
        vault.allocateFunds(490e6);

        uint256 userShares = vault.balanceOf(user);
        vm.prank(user);
        uint256 amount = vault.withdraw(userShares);

        assertGt(amount, 0);
    }

    function testRevertOnZeroStrategyAddressSet() public {
        vm.expectRevert(YVault.ZeroAddress.selector);
        vm.prank(admin);
        vault.setStrategy(address(0));
    }

    function testFullWithdrawAfterAllocation() public {
        uint256 depositAmount = 100e6;

        vm.prank(user);
        uint256 sharesMinted = vault.deposit(depositAmount);
        assertEq(sharesMinted, depositAmount);

        vm.prank(admin);
        vault.setStrategy(address(strategy));

        uint256 allocationAmount = 70e6;
        vm.prank(chainlinkKeeper);
        vault.allocateFunds(allocationAmount);

        vm.prank(user);
        uint256 withdrawnAmount = vault.withdraw(depositAmount);

        assertEq(withdrawnAmount, depositAmount);
        assertEq(token.balanceOf(user), 1_000_000e6);
        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.v_totalShares(), 0);
        assertEq(vault.v_totalAssets(), 0);
    }

    function testPartialWithdrawPullsFromStrategy() public {
        uint256 depositAmount = 100e6;

        vm.prank(user);
        uint256 sharesMinted = vault.deposit(depositAmount);
        assertEq(sharesMinted, depositAmount);

        vm.prank(admin);
        vault.setStrategy(address(strategy));

        uint256 allocationAmount = 90e6;
        vm.prank(chainlinkKeeper);
        vault.allocateFunds(allocationAmount);

        uint256 withdrawShares = 20e6;
        vm.prank(user);
        uint256 withdrawnAmount = vault.withdraw(withdrawShares);

        assertEq(withdrawnAmount, 20e6);
        assertEq(token.balanceOf(user), 1_000_000e6 - 80e6);
        assertEq(vault.balanceOf(user), 80e6);
        assertEq(vault.v_totalShares(), 80e6);
        assertEq(vault.v_totalAssets(), 80e6);
    }

    function testDepositWrongTokenDoesNothing() public {
        MockERC20 wrongToken = new MockERC20("Wrong Token", "WRONG", 6);
        wrongToken.mint(user, 500e6);

        vm.startPrank(user);
        wrongToken.approve(address(vault), type(uint256).max);
        wrongToken.transfer(address(vault), 500e6);
        vm.stopPrank();

        assertEq(vault.balanceOf(user), 0);
        assertEq(vault.v_totalShares(), 0);
        assertEq(vault.v_totalAssets(), 0);

        assertEq(MockERC20(address(vault.asset())).balanceOf(address(vault)), 0);
    }

    function testChainlinkKeeperAccessControl() public {
        vm.prank(user);
        vm.expectRevert(YVault.NotVaultOwner.selector);
        vault.allocateFunds(1e6);
    }
}
