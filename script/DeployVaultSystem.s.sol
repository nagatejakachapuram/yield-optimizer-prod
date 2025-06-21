// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {VaultFactory} from "../src/Contracts/Vaults/VaultFactory.sol";
import {YVault} from "../src/Contracts/vaults/YVault.sol";

contract DeployVaultFactoryAndVaults is Script {
    address public constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    function run() external {
        vm.startBroadcast();

        // Deploy VaultFactory with USDC and msg.sender as multisigSafe
        VaultFactory factory = new VaultFactory(USDC, msg.sender);
        console.log("VaultFactory deployed at:", address(factory));

        // Call deployVaults() to deploy both LOW and HIGH risk YVaults
        factory.deployVaults();

        // Fetch both vault addresses for clarity
        address lowRiskVault = factory.vaultByRisk(VaultFactory.RiskLevel.LOW);
        address highRiskVault = factory.vaultByRisk(VaultFactory.RiskLevel.HIGH);

        console.log("Low Risk YVault deployed at:", lowRiskVault);
        console.log("High Risk YVault deployed at:", highRiskVault);

        vm.stopBroadcast();
    }
}
