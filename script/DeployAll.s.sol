// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol"; // Import console.log for better logging

// Mocks
import {MockAavePool} from "../src/Pools/MockAavePool.sol";
import {MockMorpho} from "../src/Pools/MockMorphoPool.sol";

// Strategies
import {LowRiskAaveStrategy} from "../src/Contracts/Strategies/LowRiskAaveStrategy.sol";
import {HighRiskMorphoStrategy} from "../src/Contracts/Strategies/HighRiskMorphoStrategy.sol";

// Vaults
import {VaultFactory} from "../src/Contracts/Vaults/VaultFactory.sol";
import {YVault} from "../src/Contracts/Vaults/YVault.sol";

contract DeployAll is Script {
    // Use the official Sepolia USDC address
    address public constant USDC_SEPOLIA =
        0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    // Replace with real keeper if needed
    address public constant CHAINLINK_KEEPER =
        0x000000000000000000000000000000000000dEaD;

    uint256 public constant AAVE_APY_BPS = 500; // 5% mock APY
    uint256 public constant MORPHO_APY_BPS = 850; // 8.5% mock APY

    function run() external {
        vm.startBroadcast();

        // No need to deploy Mock USDC anymore, use the constant address
        address currentUSDC = USDC_SEPOLIA;

        // Deploy Mocks (still using mock Aave/Morpho pools)
        MockAavePool mockAave = new MockAavePool(currentUSDC, AAVE_APY_BPS);
        console.log("MockAavePool deployed at:", address(mockAave));

        MockMorpho mockMorpho = new MockMorpho(currentUSDC, MORPHO_APY_BPS);
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

        // Set Chainlink Keeper on both vaults
        YVault(lowRiskVault).setChainlinkKeeper(CHAINLINK_KEEPER);
        YVault(highRiskVault).setChainlinkKeeper(CHAINLINK_KEEPER);
        console.log("ChainlinkKeeper set for both vaults");

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

        YVault(lowRiskVault).setStrategy(address(lowRisk));
        YVault(highRiskVault).setStrategy(address(highRisk));
        console.log("Strategies assigned to each vault");

        console.log("------ Final Contract Addresses ------");
        console.log("VaultFactory:", address(factory));
        console.log("LowRiskYVault:", lowRiskVault);
        console.log("HighRiskYVault:", highRiskVault);
        console.log("LowRiskStrategy:", address(lowRisk));
        console.log("HighRiskStrategy:", address(highRisk));

        vm.stopBroadcast();
    }
}
