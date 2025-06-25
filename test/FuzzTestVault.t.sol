// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Contracts/Vaults/YVault.sol";
import "../src/Contracts/Strategies/MockERC20.sol";
import "../src/Contracts/Strategies/MockStrategy.sol";

contract YVaultFuzzTest is Test {
    YVault vault;
    MockERC20 token;
    MockStrategy strategy;

    address admin = address(0xDEAD);

    function setUp() public {
        token = new MockERC20("Mock Token", "MTK", 6);
        vault = new YVault(address(token), "TestVault", "TVLT", admin);
        strategy = new MockStrategy(address(vault), address(token));

        vm.startPrank(admin);
        vault.setStrategy(address(strategy));
        vm.stopPrank();
    }

    function testFuzzDepositsWithdrawals(uint96 amount) public {
        vm.assume(amount > 1e3 && amount < 1_000_000e6);

        token.mint(address(this), amount);
        token.approve(address(vault), amount);

        uint256 shares = vault.deposit(amount);
        assertGt(shares, 0);

        uint256 withdrawn = vault.withdraw(shares);
        assertApproxEqAbs(withdrawn, amount, 1e4);
    }

}
