// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Contracts/StrategyManager.sol";

// Minimal mock strategy for testing
contract MockStrategy is IStrategy {
    address public lastUser;
    uint256 public lastAmount;

    function execute(address user, uint256 amount) external override {
        lastUser = user;
        lastAmount = amount;
    }
}

contract StrategyManagerTest is Test {
    StrategyManager public manager;
    MockStrategy public lowRisk;
    MockStrategy public highRisk;

    address public admin = address(100);
    address public user1 = address(1);
    address public user2 = address(2);
    address public invalid = address(0xdead);

    function setUp() public {
        lowRisk = new MockStrategy();
        highRisk = new MockStrategy();

        manager = new StrategyManager(address(lowRisk), address(highRisk), admin);
    }

    function test_ConstructorSetsValues() public view {
        assertEq(manager.lowRiskStrategy(), address(lowRisk));
        assertEq(manager.highRiskStrategy(), address(highRisk));
        assertEq(manager.admin(), admin);
    }

    function test_RevertWhen_ConstructorHasZeroAddress() public {
        vm.expectRevert("Invalid address");
        new StrategyManager(address(0), address(highRisk), admin);

        vm.expectRevert("Invalid address");
        new StrategyManager(address(lowRisk), address(0), admin);

        vm.expectRevert("Invalid address");
        new StrategyManager(address(lowRisk), address(highRisk), address(0));
    }

    function test_UserCanSetLowRiskStrategy() public {
        vm.prank(user1);
        manager.setUserStrategy(address(lowRisk));

        assertEq(manager.getUserStrategy(user1), address(lowRisk));
    }

    function test_UserCanSetHighRiskStrategy() public {
        vm.prank(user2);
        manager.setUserStrategy(address(highRisk));

        assertEq(manager.getUserStrategy(user2), address(highRisk));
    }

    function test_RevertWhen_SetInvalidStrategy() public {
        vm.prank(user1);
        vm.expectRevert("Invalid strategy");
        manager.setUserStrategy(invalid);
    }

    function test_AdminCanExecuteLowRiskStrategy() public {
        vm.prank(user1);
        manager.setUserStrategy(address(lowRisk));

        vm.prank(admin);
        manager.executeLowRiskStrategy(user1, 500);

        assertEq(lowRisk.lastUser(), user1);
        assertEq(lowRisk.lastAmount(), 500);
    }

    function test_AdminCanExecuteHighRiskStrategy() public {
        vm.prank(user2);
        manager.setUserStrategy(address(highRisk));

        vm.prank(admin);
        manager.executeHighRiskStrategy(user2, 1000);

        assertEq(highRisk.lastUser(), user2);
        assertEq(highRisk.lastAmount(), 1000);
    }

    function test_RevertWhen_NonAdminExecutesStrategy() public {
        vm.prank(user1);
        manager.setUserStrategy(address(lowRisk));

        vm.prank(user1);
        vm.expectRevert("Not admin");
        manager.executeLowRiskStrategy(user1, 500);

        vm.prank(user2);
        vm.expectRevert("Not admin");
        manager.executeHighRiskStrategy(user1, 1000);
    }

    function test_RevertWhen_ExecutingLowRiskForNonOptedUser() public {
        vm.prank(user1);
        manager.setUserStrategy(address(highRisk)); // wrong strategy

        vm.prank(admin);
        vm.expectRevert("User not opted for low risk");
        manager.executeLowRiskStrategy(user1, 100);
    }

    function test_RevertWhen_ExecutingHighRiskForNonOptedUser() public {
        vm.prank(user2);
        manager.setUserStrategy(address(lowRisk)); // wrong strategy

        vm.prank(admin);
        vm.expectRevert("User not opted for high risk");
        manager.executeHighRiskStrategy(user2, 200);
    }
}
