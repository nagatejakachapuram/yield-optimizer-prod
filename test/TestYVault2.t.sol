// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console2} from "forge-std/Test.sol";
import {YVault} from "src/Contracts/Vaults/YVault.sol";
import {MockStrategy} from "../src/Contracts/Strategies/MockStrategy.sol";
import {MockERC20} from "../src/Contracts/Strategies/MockERC20.sol";

contract YVaultAdditionalTests is Test{
    YVault vault;
    MockStrategy strategy;
    MockERC20 usdc;

    address vaultOwner = address(0xABCD);
    address chainlinkKeeper = address(0x1234);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        usdc = new MockERC20("MockUSDC", "mUSDC", 6);
        strategy = new MockStrategy(address(vault),address(usdc));
        vault = new YVault(address(usdc), "YieldVault", "YV", vaultOwner);

        vm.prank(vaultOwner);
        vault.setStrategy(address(strategy));

        vm.prank(vaultOwner);
        vault.setChainlinkKeeper(chainlinkKeeper);

        usdc.mint(alice, 1_000e6);
        usdc.mint(bob, 1_000e6);

        vm.startPrank(alice);
        usdc.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(bob);
        usdc.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testPauseAndUnpause() public {
        vm.prank(vaultOwner);
        vault.pause();
        assertTrue(vault.paused());

        vm.prank(vaultOwner);
        vault.unpause();
        assertFalse(vault.paused());
    }

    function testTransferVaultOwnership() public {
        address newOwner = address(0x9999);
        vm.prank(vaultOwner);
        vault.transferVaultOwnership(newOwner);
        assertEq(vault.vaultOwnerSafe(), newOwner);
    }

    function testGetPricePerShareWhenNoShares() public view {
        uint256 price = vault.getPricePerShare();
        assertEq(price, 1e18);
    }

    function testGetPricePerShareAfterDeposit() public {
        vm.prank(alice);
        vault.deposit(100e6);
        uint256 price = vault.getPricePerShare();
        assertEq(price, 1e18);
    }

    function testRecoverERC20CannotRecoverVaultAsset() public {
        vm.expectRevert();
        vm.prank(vaultOwner);
        vault.recoverERC20(address(usdc), vaultOwner, 1);
    }

    function testRecoverERC20OtherToken() public {
        MockERC20 token = new MockERC20("Dummy", "DUM", 18);
        token.mint(address(vault), 100e18);

        vm.prank(vaultOwner);
        vault.recoverERC20(address(token), vaultOwner, 100e18);

        assertEq(token.balanceOf(vaultOwner), 100e18);
    }
}
