// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Contracts/Strategies/HighRiskMorphoStrategy.sol";
import "../src/Contracts/Strategies/MockERC20.sol";
import "../src/Pools/MockMorphoPool.sol";

contract HighRiskMorphoStrategyTest is Test {
    HighRiskMorphoStrategy strategy;
    MockERC20 usdc;
    MockMorpho morpho;

    address vault = address(this);
    address market = address(0xABCD);
    uint256 apyBasisPoints = 1000;

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "USDC", 6);
        morpho = new MockMorpho(address(usdc), apyBasisPoints);
        strategy = new HighRiskMorphoStrategy(address(usdc), address(morpho), market, vault);
        usdc.mint(address(strategy), 1_000_000e6);
        strategy.approveSpending();
    }

    function testAllocateUSDC() public {
        uint256 amount = 500_000e6;
        strategy.allocate(vault, amount);
        assertEq(morpho.balanceOf(market, address(strategy)), amount);
    }

    function testAllocateFailsIfNotVault() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert("Only vault");
        strategy.allocate(address(0xBEEF), 100e6);
    }

    function testWithdrawPartialUSDC() public {
        uint256 depositAmount = 800_000e6;
        strategy.allocate(vault, depositAmount);

        uint256 withdrawAmount = 300_000e6;
        uint256 loss = strategy.withdraw(withdrawAmount);
        assertEq(loss, 0);
        assertEq(morpho.balanceOf(market, address(strategy)), depositAmount - withdrawAmount);
    }

    function testWithdrawFailsIfNotVault() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert("Only vault");
        strategy.withdraw(100e6);
    }

    function testEstimatedTotalAssets() public {
        strategy.allocate(vault, 600_000e6);
        assertEq(strategy.estimatedTotalAssets(), 600_000e6);
    }

    function testReportReturnsCorrectValues() public {
        strategy.allocate(vault, 700_000e6);
        (uint256 gain, uint256 loss, uint256 debt) = strategy.report();
        assertEq(gain, 700_000e6);
        assertEq(loss, 0);
        assertEq(debt, 0);
    }

    function testApproveSpendingSetsMaxAllowance() public view{
        assertEq(usdc.allowance(address(strategy), address(morpho)), type(uint256).max);
    }

    function testConstructorRevertsOnZeroAddress() public {
        vm.expectRevert("Invalid address");
        new HighRiskMorphoStrategy(address(0), address(morpho), market, vault);

        vm.expectRevert("Invalid address");
        new HighRiskMorphoStrategy(address(usdc), address(0), market, vault);

        vm.expectRevert("Invalid address");
        new HighRiskMorphoStrategy(address(usdc), address(morpho), address(0), vault);

        vm.expectRevert("Invalid address");
        new HighRiskMorphoStrategy(address(usdc), address(morpho), market, address(0));
    }
}
