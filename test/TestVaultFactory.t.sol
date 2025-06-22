// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/Contracts/Vaults/VaultFactory.sol";
import "../src/Contracts/Vaults/YVault.sol";
import "../src/Contracts/Strategies/MockERC20.sol";

contract VaultFactoryTest is Test {
    VaultFactory factory;
    MockERC20 usdc;
    address multisig = address(0xBEEF);
    address owner = address(this);
    address nonOwner = address(0xABCD);

    function setUp() public {
        usdc = new MockERC20("Mock USDC", "USDC", 6);
        factory = new VaultFactory(address(usdc), multisig);
    }

    function testConstructorInitializesCorrectly() public view {
        assertEq(factory.USDC(), address(usdc));
        assertEq(factory.multisigSafe(), multisig);
    }

    function testDeployVaultsSetsCorrectVaults() public {
        factory.deployVaults();

        address lowRiskVault = factory.getVaultByRisk(VaultFactory.RiskLevel.LOW);
        address highRiskVault = factory.getVaultByRisk(VaultFactory.RiskLevel.HIGH);

        assertTrue(lowRiskVault != address(0));
        assertTrue(highRiskVault != address(0));

        YVault low = YVault(lowRiskVault);
        YVault high = YVault(highRiskVault);

        assertEq(low.v_name(), "AI Vault - Low Risk");
        assertEq(low.v_symbol(), "aiLOW");
        assertEq(high.v_name(), "AI Vault - High Risk");
        assertEq(high.v_symbol(), "aiHIGH");
    }

    function testDeployVaultsOnlyOnce() public {
        factory.deployVaults();
        vm.expectRevert(VaultFactory.VaultAlreadyDeployed.selector);
        factory.deployVaults();
    }

    function testUpdateMultisigSafe() public {
        address newSafe = address(0xCAFE);
        factory.updateMultisigSafe(newSafe);
        assertEq(factory.multisigSafe(), newSafe);
    }

    function testUpdateMultisigSafeRevertsOnZero() public {
        vm.expectRevert(VaultFactory.MultisigZeroAddress.selector);
        factory.updateMultisigSafe(address(0));
    }

    function testNonOwnerCannotDeployOrUpdateMultisig() public {
        vm.startPrank(nonOwner);

        vm.expectRevert("Ownable: caller is not the owner");
        factory.deployVaults();

        vm.expectRevert("Ownable: caller is not the owner");
        factory.updateMultisigSafe(address(0x1234));

        vm.stopPrank();
    }

    function testConstructorRevertsOnZeroAddresses() public {
        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        new VaultFactory(address(0), multisig);

        vm.expectRevert(VaultFactory.ZeroAddress.selector);
        new VaultFactory(address(usdc), address(0));
    }
}
