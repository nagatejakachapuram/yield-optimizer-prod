//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.28;
import "forge-std/Script.sol";
import "forge-std/console.sol";

import {AutomationOwner} from "../src/Contracts/Vaults/AutomationOwner.sol";
import {YVault} from "../src/Contracts/Vaults/YVault.sol";

contract TransferOwnership is Script {
    address public constant LOW_VAULT = 0xb32a6FF65dcC2099513970EA5c1eaA87fe564253; 
    address public constant HIGH_VAULT = 0x721bF349E453cbFB68536d3a5757A70B74D84279; 

    function run() external {
        vm.startBroadcast();

        AutomationOwner lowVaultOwner = new AutomationOwner(LOW_VAULT);
        console.log("Low Vault Owner:", address(lowVaultOwner));

        AutomationOwner highVaultOwner = new AutomationOwner(HIGH_VAULT);
        console.log("High Vault Owner:", address(highVaultOwner));

        YVault(LOW_VAULT).transferVaultOwnership(address(lowVaultOwner));
        YVault(HIGH_VAULT).transferVaultOwnership(address(highVaultOwner));

        vm.stopBroadcast();
    }
}