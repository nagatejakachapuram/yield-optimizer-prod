// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Contracts/Vault.sol"; 

contract DeployVault is Script {
    address constant USDC = 0x84804B7890dcE731c7791dF63aBDE9ccB74d6a02; // MockUSDC on Sepolia
    address constant ADMIN = 0x05e62059FEDa53EA732889602D0F777Af1a66386; // replace with your address

    function run() external {
        vm.startBroadcast();

        Vault vault = new Vault(USDC, ADMIN);

        console2.log("Vault deployed at:", address(vault));

        vm.stopBroadcast();
    }
}
