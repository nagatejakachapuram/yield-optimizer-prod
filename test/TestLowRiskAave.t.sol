// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Contracts/Strategies/LowRiskAaveStrategy.sol";
import "../src/Contracts/Strategies/MockERC20.sol";
import "../src/Pools/MockAavePool.sol";

contract LowRiskAaveStrategyTest is Test {
    LowRiskAaveStrategy strategy;
    MockERC20 usdc;
    MockAavePool aavePool;

    address vault = address(this);
    uint256 apyBasisPoints = 1000;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "USDC", 6);
        aavePool = new MockAavePool(address(usdc), apyBasisPoints);
        strategy = new LowRiskAaveStrategy(address(usdc), address(aavePool), vault);

        // Mint and transfer USDC to strategy for allocation tests
        usdc.mint(address(strategy), 1_000_000e6);

        // Approve max allowance for aavePool
        strategy.approveSpending();
    }

    function testAllocate() public {
        uint256 amount = 500_000e6;

        // Allocate funds
        strategy.allocate(vault, amount);

        // Check that the aavePool registered the supply
        (uint256 totalCollateral, , , , , ) = aavePool.getUserAccountData(address(strategy));
        assertEq(totalCollateral, amount);
    }

    function testAllocateOnlyVault() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("Only vault");
        strategy.allocate(address(0xBEEF), 100e6);
    }

    function testWithdrawPartial() public {
        uint256 depositAmount = 800_000e6;
        strategy.allocate(vault, depositAmount);

        uint256 withdrawAmount = 300_000e6;
        uint256 loss = strategy.withdraw(withdrawAmount);
        assertEq(loss, 0);

        (uint256 totalCollateral, , , , , ) = aavePool.getUserAccountData(address(strategy));
        assertEq(totalCollateral, depositAmount - withdrawAmount);
    }

    function testWithdrawPartialWithLoss() public {
    // Supply 500k USDC but try to withdraw 600k
    uint256 depositAmount = 500_000e6;
    strategy.allocate(vault, depositAmount);

    uint256 withdrawAmount = 600_000e6;
    uint256 loss = strategy.withdraw(withdrawAmount);

    // Expect full loss since withdrawal failed
    assertEq(loss, withdrawAmount); // 600k loss

    // Funds should still be in the pool since withdrawal failed
    (uint256 totalCollateral, , , , , ) = aavePool.getUserAccountData(address(strategy));
    assertEq(totalCollateral, depositAmount); // should still be 500k
}


    function testWithdrawOnlyVault() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert("Only vault");
        strategy.withdraw(100e6);
    }

    function testEstimatedTotalAssets() public {
        strategy.allocate(vault, 600_000e6);
        uint256 assets = strategy.estimatedTotalAssets();
        assertEq(assets, 600_000e6);
    }

    function testReport() public {
        strategy.allocate(vault, 700_000e6);
        (uint256 gain, uint256 loss, uint256 debtPayment) = strategy.report();
        assertEq(gain, 700_000e6);
        assertEq(loss, 0);
        assertEq(debtPayment, 0);
    }

    function testApproveSpending() public view {
        assertEq(usdc.allowance(address(strategy), address(aavePool)), type(uint256).max);
    }
}
