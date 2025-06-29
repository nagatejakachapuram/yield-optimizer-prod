// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MockAavePool} from "../src/Pools/MockAavePool.sol";
import {MockMorpho} from "../src/Pools/MockMorphoPool.sol";
import {VaultFactory} from "../src/Contracts/Vaults/VaultFactory.sol";
import {YVault} from "../src/Contracts/Vaults/YVault.sol";

contract DeployVaults is Script {
    address public constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant CHAINLINK_KEEPER = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant AAVE_APY_BPS = 500;
    uint256 public constant MORPHO_APY_BPS = 850;

    function run() external {
        vm.startBroadcast();

        // Deploy mocks
        MockAavePool mockAave = new MockAavePool(USDC_SEPOLIA, AAVE_APY_BPS);
        console.log("MockAavePool:", address(mockAave));

        MockMorpho mockMorpho = new MockMorpho(USDC_SEPOLIA, MORPHO_APY_BPS);
        console.log("MockMorpho:", address(mockMorpho));

        // Deploy VaultFactory
        VaultFactory factory = new VaultFactory(USDC_SEPOLIA, msg.sender);
        console.log("VaultFactory:", address(factory));

        // Deploy Vaults
        factory.deployVaults();
        address lowRiskVault = factory.vaultByRisk(VaultFactory.RiskLevel.LOW);
        address highRiskVault = factory.vaultByRisk(VaultFactory.RiskLevel.HIGH);

        console.log("LowRiskVault:", lowRiskVault);
        console.log("HighRiskVault:", highRiskVault);

        // Set Chainlink Keeper
        YVault(lowRiskVault).setChainlinkKeeper(CHAINLINK_KEEPER);
        YVault(highRiskVault).setChainlinkKeeper(CHAINLINK_KEEPER);

        console.log("ChainlinkKeeper set");

        vm.stopBroadcast();
    }
}
