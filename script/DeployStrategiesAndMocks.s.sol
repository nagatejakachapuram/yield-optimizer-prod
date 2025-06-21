// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol"; // Import console.log for better logging

// Mocks
import {MockAavePool} from "../src/Pools/MockAavePool.sol";
import {MockMorpho} from "../src/Pools/MockMorphoPool.sol";

// Strategies
import {LowRiskAaveStrategy} from "../src/Contracts/strategies/LowRiskAaveStrategy.sol";
import {HighRiskMorphoStrategy} from "../src/Contracts/strategies/HighRiskMorphoStrategy.sol";

// Vaults
import {VaultFactory} from "../src/Contracts/Vaults/VaultFactory.sol";

contract DeployAll is Script {
    // Use the official Sepolia USDC address
    address public constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    uint256 public constant AAVE_APY_BPS = 500; // 5% mock APY

    function run() external {
        vm.startBroadcast();

        // No need to deploy Mock USDC anymore, use the constant address
        address currentUSDC = USDC_SEPOLIA;

        // Deploy Mocks (still using mock Aave/Morpho pools)
        MockAavePool mockAave = new MockAavePool(currentUSDC, AAVE_APY_BPS);
        console.log("MockAavePool deployed at:", address(mockAave));

        MockMorpho mockMorpho = new MockMorpho(currentUSDC);
        console.log("MockMorpho deployed at:", address(mockMorpho));

        // Deploy VaultFactory
        VaultFactory factory = new VaultFactory(currentUSDC, msg.sender);
        console.log("VaultFactory deployed at:", address(factory));

        // Deploy Vaults via factory
        factory.deployVaults();
        address lowRiskVault = factory.vaultByRisk(VaultFactory.RiskLevel.LOW);
        address highRiskVault = factory.vaultByRisk(
            VaultFactory.RiskLevel.HIGH
        );

        console.log("Low Risk YVault deployed at:", lowRiskVault);
        console.log("High Risk YVault deployed at:", highRiskVault);

        // Deploy Strategies with corresponding vaults
        LowRiskAaveStrategy lowRisk = new LowRiskAaveStrategy(
            currentUSDC,
            address(mockAave),
            lowRiskVault
        );
        console.log("LowRiskAaveStrategy deployed at:", address(lowRisk));

        HighRiskMorphoStrategy highRisk = new HighRiskMorphoStrategy(
            currentUSDC,
            address(mockMorpho),
            currentUSDC, // usdcMarket for Morpho will be the actual USDC
            highRiskVault
        );
        console.log("HighRiskMorphoStrategy deployed at:", address(highRisk));

        // 🔐 Approve spending
        lowRisk.approveSpending();
        highRisk.approveSpending();
        console.log("Approvals set for both strategies");

        vm.stopBroadcast();
    }
}