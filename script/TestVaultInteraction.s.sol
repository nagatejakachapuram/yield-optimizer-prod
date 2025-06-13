// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Contracts/Vault.sol";
import {MockUSDC} from "./DeployMockSwap.s.sol";

contract TestVaultInteraction is Script {
    address vaultAddr = 0x03e20cd87BeA744239662A22362C364f8eB5Ef4D;
    address usdcAddr = 0x84804B7890dcE731c7791dF63aBDE9ccB74d6a02;

    function run() public {
        vm.startBroadcast();

        Vault vault = Vault(payable(vaultAddr));
        MockUSDC usdc = MockUSDC(usdcAddr);

        // Mint USDC to yourself (your EOA)
        usdc.mint(msg.sender, 1000e6);

        // Approve Vault
        usdc.approve(vaultAddr, 1000e6);

        // Deposit into Vault
        vault.deposit(1000e6);

        vm.stopBroadcast();
    }
}
