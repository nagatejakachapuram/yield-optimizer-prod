// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDY.sol";

contract DeployMockUSDY is Script {
    function run() public returns (MockUSDY) {
        vm.startBroadcast();

        MockUSDY usdy = new MockUSDY();

        vm.stopBroadcast();
        return usdy;
    }
} 