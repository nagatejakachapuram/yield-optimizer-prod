// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {Vault} from "../../src/Testing_Phase/Main Contracts/Vault_Mock.sol";
import {StrategyManager} from "../../src/Testing_Phase/Main Contracts/Strategy_Manager.sol";
import "../../src/Testing_Phase/Mocks/MockSwap.sol";
import "../../src/Testing_Phase/Mocks/MockUSDY.sol";
import "../../src/Testing_Phase/Mocks/MockSwap.sol";
import "../../src/Testing_Phase/Mocks/MockUSDC.sol";
import "../../src/Testing_Phase/Mocks/MockStrategy.sol";
import {MockPriceFeed} from "../../src/Testing_Phase/Mocks/MockPriceFeed.sol";
import {DeployAllContracts} from "../../script/Testing_Phase/DeployAllContracts.s.sol";

contract VaultTest is Test {
    Vault public vault;
    StrategyManager public strategyManager;
    MockUSDC public usdc;
    MockUSDY public usdy;
    MockSwap public mockSwap;
    MockStrategy public lowRiskStrategy;
    MockStrategy public highRiskStrategy;
    MockPriceFeed public mockPriceFeed;

    // Test accounts
    address public deployer;
    address public user1;
    address public user2;
    address public alice;
    address public bob;
    address public stranger;
    address public newAdminCandidate;

    function setUp() public {
        deployer = address(this);
        alice = vm.addr(4);
        bob = vm.addr(5);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        DeployAllContracts script = new DeployAllContracts();
        (
            Vault _vault,
            StrategyManager _strategyManager,
            MockUSDC _usdc,
            MockUSDY _usdy,
            MockSwap _mockSwap,
            MockPriceFeed _mockPriceFeed,
            MockStrategy _lowRiskStrategy,
            MockStrategy _highRiskStrategy
        ) = script.run();

        vault = _vault;
        strategyManager = _strategyManager;
        usdc = _usdc;
        usdy = _usdy;
        mockSwap = _mockSwap;
        mockPriceFeed = _mockPriceFeed;
        lowRiskStrategy = _lowRiskStrategy;
        highRiskStrategy = _highRiskStrategy;

        // Labels for test readability
        vm.label(address(vault), "Vault");
        vm.label(address(usdc), "USDC");
        vm.label(address(usdy), "USDY");
        vm.label(address(mockSwap), "MockSwap");
        vm.label(address(strategyManager), "StrategyManager");
        vm.label(address(lowRiskStrategy), "LowRiskStrategy");
        vm.label(address(highRiskStrategy), "HighRiskStrategy");

        // Mint USDC to users
        usdc.mint(user1, 100_000 * 10 ** 6);
        usdc.mint(user2, 100_000 * 10 ** 6);
    }

    // --- Basic Interaction Tests ---

    function test_InitialState() public view {
        assertEq(vault.admin(), deployer, "Admin should be deployer");
        assertEq(
            strategyManager.owner(),
            deployer,
            "StrategyManager owner should be deployer"
        );
        assertEq(vault.totalValueLocked(), 0, "Initial TVL should be 0");
        assertFalse(vault.paused(), "Vault should not be paused initially");
        assertTrue(
            vault.approvedStrategies(address(lowRiskStrategy)),
            "Low risk strategy should be approved"
        );
        assertTrue(
            vault.approvedStrategies(address(highRiskStrategy)),
            "High risk strategy should be approved"
        );
    }

    function test_DepositUSDC() public {
        uint256 depositAmount = 1000 * 10 ** 6; // 1,000 USDC

        // Mint USDC to Alice so she has funds to deposit
        usdc.mint(alice, 10_000 * 10 ** 6);

        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);

        // Alice deposits
        vault.deposit(depositAmount);

        // Assertions
        assertEq(
            usdc.balanceOf(alice),
            (10_000 - 1_000) * 10 ** 6,
            "Alice's USDC balance incorrect after deposit"
        );
        assertEq(
            usdc.balanceOf(address(vault)),
            depositAmount,
            "Vault's USDC balance incorrect after deposit"
        );
        assertEq(
            vault.userDeposits(alice),
            depositAmount,
            "Alice's recorded deposit incorrect"
        );
        assertEq(
            vault.totalValueLocked(),
            depositAmount,
            "TVL incorrect after deposit"
        );
        vm.stopPrank();
    }

    function test_DepositUSDC_MultipleDeposits() public {
        uint256 depositAmount1 = 500 * 10 ** 6;
        uint256 depositAmount2 = 700 * 10 ** 6;
        uint256 totalDeposit = depositAmount1 + depositAmount2;

        // Mint USDC to Alice so she has enough balance to deposit
        usdc.mint(alice, 10_000 * 10 ** 6);

        vm.startPrank(alice);
        usdc.approve(address(vault), totalDeposit);
        vault.deposit(depositAmount1);
        vault.deposit(depositAmount2);

        assertEq(
            usdc.balanceOf(alice),
            (10_000 - 1_200) * 10 ** 6,
            "Alice's USDC balance incorrect after multiple deposits"
        );
        assertEq(
            vault.userDeposits(alice),
            totalDeposit,
            "Alice's recorded deposits incorrect"
        );
        assertEq(
            vault.totalValueLocked(),
            totalDeposit,
            "TVL incorrect after multiple deposits"
        );
        vm.stopPrank();
    }

    function test_DepositUSDC_ZeroAmountReverts() public {
        vm.startPrank(alice);
        vm.expectRevert("Amount must be greater than zero");
        vault.deposit(0);
        vm.stopPrank();
    }

    function test_WithdrawUSDC() public {
        uint256 depositAmount = 1000 * 10 ** 6;
        uint256 withdrawAmount = 500 * 10 ** 6;

        usdc.mint(alice, 10_000 * 10 ** 6);

        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);

        vault.withdraw(withdrawAmount);

        assertEq(
            usdc.balanceOf(alice),
            (10_000 - 1_000 + 500) * 10 ** 6,
            "Alice's USDC balance incorrect after withdraw"
        );
        assertEq(
            usdc.balanceOf(address(vault)),
            depositAmount - withdrawAmount,
            "Vault's USDC balance incorrect after withdraw"
        );
        assertEq(
            vault.userDeposits(alice),
            depositAmount - withdrawAmount,
            "Alice's recorded deposit incorrect after withdraw"
        );
        assertEq(
            vault.totalValueLocked(),
            depositAmount - withdrawAmount,
            "TVL incorrect after withdraw"
        );
        vm.stopPrank();
    }

    function test_WithdrawUSDC_FullAmount() public {
        uint256 depositAmount = 1000 * 10 ** 6;

        usdc.mint(alice, 10_000 * 10 ** 6);

        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);

        vault.withdraw(depositAmount);

        assertEq(
            usdc.balanceOf(alice),
            10_000 * 10 ** 6,
            "Alice's USDC balance incorrect after full withdraw"
        );
        assertEq(
            usdc.balanceOf(address(vault)),
            0,
            "Vault's USDC balance incorrect after full withdraw"
        );
        assertEq(
            vault.userDeposits(alice),
            0,
            "Alice's recorded deposit incorrect after full withdraw"
        );
        assertEq(
            vault.totalValueLocked(),
            0,
            "TVL incorrect after full withdraw"
        );
        vm.stopPrank();
    }

    function test_WithdrawUSDC_MoreThanDepositedReverts() public {
        uint256 depositAmount = 500 * 10 ** 6;
        uint256 withdrawAmount = 1000 * 10 ** 6;

        usdc.mint(alice, 10_000 * 10 ** 6);

        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);

        vm.expectRevert("Insufficient balance");
        vault.withdraw(withdrawAmount);
        vm.stopPrank();
    }

    function test_WithdrawUSDC_ZeroAmountReverts() public {
        vm.startPrank(alice);
        vm.expectRevert("Amount must be greater than zero");
        vault.withdraw(0);
        vm.stopPrank();
    }

    // --- Strategy Management Tests ---

    function test_SetUserStrategy() public {
        vm.startPrank(alice);
        strategyManager.setUserStrategy(address(lowRiskStrategy));
        assertEq(
            strategyManager.getUserStrategy(alice),
            address(lowRiskStrategy),
            "Alice's strategy preference not set"
        );
        vm.stopPrank();
    }

    function test_SetUserStrategy_InvalidStrategyReverts() public {
        vm.startPrank(alice);
        vm.expectRevert("Invalid strategy");
        strategyManager.setUserStrategy(address(stranger));
        vm.stopPrank();
    }

    // --- Fund Allocation Tests (Simulating AI Agent Call) ---

    function test_AllocateFunds_ToUserPreferredStrategy() public {
        uint256 depositAmount = 1000 * 10 ** 6;
        // Set up Chainlink admin before calling allocateFunds
        address chainlinkAdmin = vm.addr(123); 
        usdc.mint(alice, depositAmount);
        vm.prank(deployer);
        vault.setChainlinkAdmin(chainlinkAdmin);
        

        vm.startPrank(alice);
        usdc.approve(address(vault), depositAmount);
        vault.deposit(depositAmount);
        strategyManager.setUserStrategy(address(highRiskStrategy)); // Alice prefers high risk
        vm.stopPrank();

        vm.prank(deployer);
        vault.setApprovedStrategy(address(highRiskStrategy), true);

        vm.startPrank(chainlinkAdmin);
        uint256 vaultUSDCBefore = usdc.balanceOf(address(vault));
        uint256 highRiskStrategyUSDCBefore = usdc.balanceOf(
            address(highRiskStrategy)
        );

        vault.allocateFunds(alice, depositAmount, address(highRiskStrategy));

        // Assertions
        assertEq(
            usdc.balanceOf(address(vault)),
            vaultUSDCBefore - depositAmount,
            "Vault's USDC should decrease after allocation"
        );
        assertEq(
            usdc.balanceOf(address(highRiskStrategy)),
            highRiskStrategyUSDCBefore + depositAmount,
            "High risk strategy should receive funds"
        );
        assertEq(
            vault.userDeposits(alice),
            0,
            "Alice's recorded deposit should be 0 after full allocation"
        );

        assertEq(
            vault.totalValueLocked(),
            depositAmount,
            "TVL should remain the same after allocation"
        );
        vm.stopPrank();
    }

    function test_AllocateFunds_InvalidStrategyReverts() public {
    uint256 depositAmount = 1000 * 10 ** 6;

    address chainlinkAdmin = vm.addr(123);
    usdc.mint(alice, depositAmount);

    vm.prank(alice);
    usdc.approve(address(vault), depositAmount);

    vm.prank(alice);
    vault.deposit(depositAmount);

    vm.prank(deployer);
    vault.setChainlinkAdmin(chainlinkAdmin);

    vm.startPrank(chainlinkAdmin);
    vm.expectRevert("Strategy not approved");
    vault.allocateFunds(alice, depositAmount, address(stranger));
    vm.stopPrank();
}


    // --- Swap Functionality Tests ---
    function test_SwapUSDYtoUSDC() public {
        uint256 usdyAmount = 100 * 10 ** 18;

        // Mint to Alice from owner context
        vm.startPrank(usdy.owner());
        usdy.mint(alice, usdyAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        uint256 aliceUSDCBefore = usdc.balanceOf(alice);
        uint256 aliceUSDYBefore = usdy.balanceOf(alice);

        usdy.approve(address(vault), usdyAmount);
        vault.swapUSDYtoUSDC(usdyAmount);

        assertEq(
            usdy.balanceOf(alice),
            aliceUSDYBefore - usdyAmount,
            "Alice's USDY should decrease"
        );

        assertEq(
            usdc.balanceOf(alice),
            aliceUSDCBefore,
            "Alice's USDC balance should not change directly"
        );

        assertEq(
            vault.userDeposits(alice),
            usdyAmount / 1e12,
            "Alice's Vault deposit should increase by equivalent USDC"
        );
        assertEq(
            usdc.balanceOf(address(mockSwap)),
            (500_000 - 100) * 10 ** 6,
            "MockSwap USDC liquidity reduced"
        );
        vm.stopPrank();
    }

    function test_SwapUSDYtoUSDC_ZeroAmountReverts() public {
        vm.startPrank(alice);
        vm.expectRevert("Amount must be greater than 0");
        vault.swapUSDYtoUSDC(0);
        vm.stopPrank();
    }

    // --- Pausable Tests ---

    function test_PauseAndUnpause() public {
        address admin = vault.admin();
        // Give Alice initial balance
        deal(address(usdc), alice, 10_000 * 10 ** 6);

        vm.startPrank(admin);
        vault.pause();
        assertTrue(vault.paused(), "Vault should be paused");

        vault.unpause();
        assertFalse(vault.paused(), "Vault should be unpaused");
        vm.stopPrank();

        vm.startPrank(alice);
        usdc.approve(address(vault), 1_000 * 10 ** 6);
        vault.deposit(1_000 * 10 ** 6);
        vm.stopPrank();
    }
}
