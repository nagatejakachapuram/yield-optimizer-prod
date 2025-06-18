// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../../src/Contracts/Vault.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockStrategy is IStrategy {
    address public lastUser;
    uint256 public lastAmount;

    function execute(address user, uint256 amount) external override {
        lastUser = user;
        lastAmount = amount;
    }
}

contract VaultTest is Test {
    Vault public vault;
    MockUSDC public usdc;
    MockStrategy public strategy;

    address public admin = address(1);
    address public chainlinkAdmin = address(2);
    address public user = address(3);

    error NotChainlinkAdmin();
    error NotAdmin();

    function setUp() public {
        vm.startPrank(admin);
        usdc = new MockUSDC();
        vault = new Vault(address(usdc), admin);
        strategy = new MockStrategy();
        vault.setChainlinkAdmin(chainlinkAdmin);
        vm.stopPrank();

        usdc.mint(user, 1000e6);
        vm.prank(user);
        usdc.approve(address(vault), type(uint256).max);
    }

    function testDepositAndWithdraw() public {
        vm.prank(user);
        vault.deposit(500e6);
        assertEq(vault.userDeposits(user), 500e6);

        vm.prank(user);
        vault.withdraw(200e6);
        assertEq(vault.userDeposits(user), 300e6);
    }

    function testSetApprovedStrategyAndAllocate() public {
        // Admin approves strategy
        vm.prank(admin);
        vault.setApprovedStrategy(address(strategy), true);

        // User deposits
        vm.prank(user);
        vault.deposit(400e6);

        // Chainlink admin allocates
        vm.prank(chainlinkAdmin);
        vault.allocateFunds(user, 300e6, address(strategy));

        assertEq(vault.userDeposits(user), 100e6);
        assertEq(strategy.lastUser(), user);
        assertEq(strategy.lastAmount(), 300e6);
    }

    function testPauseAndUnpause() public {
        vm.prank(admin);
        vault.pause();

        vm.prank(user);
        vm.expectRevert("Pausable: paused");
        vault.deposit(100e6);

        vm.prank(admin);
        vault.unpause();

        vm.prank(user);
        vault.deposit(100e6);
        assertEq(vault.userDeposits(user), 100e6);
    }

    function testAdminOwnershipTransfer() public {
        address newAdmin = address(4);

        vm.prank(admin);
        vault.transferAdminOwnership(newAdmin);

        vm.prank(newAdmin);
        vault.acceptAdminOwnership();

        // Now new admin should be able to pause
        vm.prank(newAdmin);
        vault.pause();
    }

    function testRejectEth() public {
        vm.expectRevert();
        (bool success, ) = address(vault).call{value: 1 ether}("");
        assertTrue(success);
    }

    function test_RevertWhen_NonAdminSetsApprovedStrategy() public {
        vm.prank(user);
        vm.expectRevert(NotAdmin.selector);
        vault.setApprovedStrategy(address(strategy), true);
    }

    function test_RevertWhen_NonChainlinkAdminCallsAllocate() public {
        vm.prank(admin);
        vault.setApprovedStrategy(address(strategy), true);

        vm.prank(user);
        vault.deposit(400e6);

        vm.prank(user); // not chainlinkAdmin
        vm.expectRevert(NotChainlinkAdmin.selector);
        vault.allocateFunds(user, 100e6, address(strategy));
    }

    function test_RevertWhen_AllocateMoreThanDeposit() public {
        vm.prank(admin);
        vault.setApprovedStrategy(address(strategy), true);

        vm.prank(user);
        vault.deposit(200e6);

        vm.prank(chainlinkAdmin);
        vm.expectRevert("Insufficient balance");
        vault.allocateFunds(user, 300e6, address(strategy));
    }

    function test_RevertWhen_DepositZeroAmount() public {
        vm.prank(user);
        vm.expectRevert("Amount must be greater than zero");
        vault.deposit(0);
    }

    function test_RevertWhen_WithdrawMoreThanDeposited() public {
        vm.prank(user);
        vault.deposit(100e6);

        vm.prank(user);
        vm.expectRevert("Insufficient balance");
        vault.withdraw(200e6);
    }

    function test_RevertWhen_AllocatingToUnapprovedStrategy() public {
        vm.prank(user);
        vault.deposit(100e6);

        vm.prank(chainlinkAdmin);
        vm.expectRevert("Strategy not approved");
        vault.allocateFunds(user, 50e6, address(strategy));
    }

    function test_AdminCanRecoverNonCoreToken() public {
        address randomToken = address(new MockUSDC());
        MockUSDC(randomToken).mint(address(vault), 100e6);

        vm.prank(admin);
        vault.recoverERC20(IERC20(randomToken), 100e6);

        assertEq(MockUSDC(randomToken).balanceOf(admin), 100e6);
    }

    function test_RevertWhen_NonAdminRecoversToken() public {
        address randomToken = address(new MockUSDC());
        MockUSDC(randomToken).mint(address(vault), 100e6);

        vm.prank(user);
        vm.expectRevert(NotAdmin.selector);
        vault.recoverERC20(IERC20(randomToken), 100e6);
    }
}
