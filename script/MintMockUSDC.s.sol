// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {MockUSDC} from "./DeployMockSwap.s.sol";


contract MintMockUSDC is Script {
    function run() public {
        vm.startBroadcast();

        MockUSDC usdc = MockUSDC(0x84804B7890dcE731c7791dF63aBDE9ccB74d6a02);
        usdc.mint(msg.sender, 1_000_000 * 10**6);

        vm.stopBroadcast();
    }
}
