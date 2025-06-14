// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Contracts/Vault.sol";

contract DeployVault is Script {
    function run() external {
        // Get deployer's private key from command line
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Vault contract with hardcoded addresses
        Vault vault = new Vault(
            0xAd932382b6a95092F18A842e6792312959345a5e,  // MockUSDC
            0x886aD11d305430A31a9b6c8ee9C85cf344bB87DB,  // MockUSDY
            0xa50E3e2D73BAcaC44d50b8AE7574EB6407990986,  // MockSwap
            msg.sender  // Admin (deployer)
        );

        vm.stopBroadcast();

        // Log deployment information
        console.log("Vault deployed to:", address(vault));
    }
}
