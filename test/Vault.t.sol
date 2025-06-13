// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Contracts/Vault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract MockERC20 is ERC20 {
    uint8 private immutable _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}


contract MockStrategy is IStrategy {
    address public lastUser;
    uint256 public lastAmount;
    IERC20 public token;

    constructor(address _token) {
        token = IERC20(_token);
    }

    function execute(address user, uint256 amount) external override {
        lastUser = user;
        lastAmount = amount;

        // Pull funds from the Vault (msg.sender)
        token.transferFrom(msg.sender, address(this), amount);
    }
}

contract VaultTest is Test {
    Vault vault;
    MockERC20 usdc;
    MockStrategy strategy;
    address admin;
    address user;
    address other;

    function setUp() public {
        admin = address(1);
        user = address(2);
        other = address(3);
        vm.label(admin, "Admin");
        vm.label(user, "User");
        vm.label(other, "Other");

        usdc = new MockERC20("Mock USDC", "USDC", 6);
        strategy = new MockStrategy(address(usdc));

        vault = new Vault(address(usdc), admin);

        usdc.mint(user, 1000e6);
        vm.prank(admin);
        vault.setApprovedStrategy(address(strategy), true);
    }

    function test_DepositAndWithdraw() public {
        vm.startPrank(user);
        usdc.approve(address(vault), 500e6);
        vault.deposit(500e6);
        assertEq(vault.getUserDeposits(), 500e6);
        assertEq(usdc.balanceOf(address(vault)), 500e6);

        vault.withdraw(200e6);
        assertEq(vault.getUserDeposits(), 300e6);
        assertEq(usdc.balanceOf(user), 700e6);
        vm.stopPrank();
    }

    function test_RevertOnZeroDeposit() public {
        vm.startPrank(user);
        usdc.approve(address(vault), 0);
        vm.expectRevert("Amount must be greater than zero");
        vault.deposit(0);
        vm.stopPrank();
    }

    function test_RevertOnExcessWithdraw() public {
        vm.startPrank(user);
        usdc.approve(address(vault), 300e6);
        vault.deposit(300e6);
        vm.expectRevert("Insufficient balance");
        vault.withdraw(400e6);
        vm.stopPrank();
    }

    function test_AdminOnlyStrategyApproval() public {
        vm.prank(user);
        vm.expectRevert(Vault.NotAdmin.selector);
        vault.setApprovedStrategy(address(0x123), true);
    }

    function test_RevertWhen_AllocatingWithoutEnoughBalance() public {
        vm.prank(admin);
        vm.expectRevert("Insufficient balance");
        vault.allocateFunds(user, 100e6, address(strategy));
    }

    function test_RevertWhen_StrategyNotApproved() public {
        vm.startPrank(user);
        usdc.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        address unapprovedStrategy = address(new MockStrategy(address(usdc)));

        vm.startPrank(admin);
        vm.expectRevert("Strategy not approved");
        vault.allocateFunds(user, 100e6, unapprovedStrategy);
        vm.stopPrank();
    }

    function test_RevertWhen_StrategyNotContract() public {
        vm.startPrank(user);
        usdc.approve(address(vault), 100e6);
        vault.deposit(100e6);
        vm.stopPrank();

        vm.startPrank(admin);
        vault.setApprovedStrategy(other, true); // not a contract
        vm.expectRevert("Strategy must be a contract");
        vault.allocateFunds(user, 100e6, other);
        vm.stopPrank();
    }

    function test_SuccessfulFundAllocation() public {
        vm.startPrank(user);
        usdc.approve(address(vault), 200e6);
        vault.deposit(200e6);
        vm.stopPrank();

        vm.prank(admin);
        vault.allocateFunds(user, 200e6, address(strategy));

        assertEq(vault.getUserDeposits(), 0);
        assertEq(usdc.balanceOf(address(strategy)), 200e6);
    }

    function test_RevertOnFallbackAndReceive() public {
        (bool successFallback, ) = address(vault).call{value: 1 ether}("");
        assertFalse(successFallback);

        (bool successReceive, ) = address(vault).call{value: 1 ether}(
            abi.encodeWithSignature("nonexistentFunction()")
        );
        assertFalse(successReceive);
    }
}
