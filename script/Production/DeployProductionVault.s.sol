// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";

// Contracts
import "../../src/Contracts/Vault.sol";
import "../../src/Contracts/StrategyManager.sol";
import "../../src/Strategies/Core-Routers/LowRiskStrategy.sol";
import "../../src/Strategies/Core-Routers/HighRiskStrategy.sol";
import "../../src/Strategies/Pools/AaveStrategy.sol";
import "../../src/Strategies/Pools/PendleStrategy.sol";

// Mocks
import "../../src/Strategies/Mocks/MockAavePool.sol";
import "../../src/Strategies/Mocks/MockPendleMarket.sol";

// Real Sepolia USDC
address constant USDC_ADDRESS = 0x1c7D4B196cb0c7b01D743928b76Bbc59EBa05B0F;
address constant DEPLOYER_ADMIN_ADDRESS = 0x05e62059FEDa53EA732889602D0F777Af1a66386;
address constant CHAINLINK_AUTOMATION_ADMIN_ADDRESS = 0x05e62059FEDa53EA732889602D0F777Af1a66386;

contract DeployMockVault is Script {
    function run()
        public
        returns (
            Vault vault,
            StrategyManager strategyManager,
            LowRiskStrategy lowRiskStrategy,
            HighRiskStrategy highRiskStrategy,
            AaveStrategy aaveStrategy,
            PendleStrategy pendleStrategy,
            MockAavePool mockAave,
            MockPendleMarket mockPendle,
            MockPT ptToken,
            MockYT ytToken
        )
    {
        // Read AI-suggested APYs from environment (set via script before)
        uint256 lowRiskApy = vm.envUint("LOW_RISK_APY");
        uint256 highRiskApy = vm.envUint("HIGH_RISK_APY");

        vm.startBroadcast();

        console.log("=== Deploying Mock Tokens for Pendle ===");
        ptToken = new MockPT();
        ytToken = new MockYT();
        console.log("MockPT deployed at:", address(ptToken));
        console.log("MockYT deployed at:", address(ytToken));

        console.log("\n=== Deploying Mock Strategy Pools (using AI APYs) ===");

        mockAave = new MockAavePool(USDC_ADDRESS, lowRiskApy);
        console.log("MockAavePool deployed with APY:", lowRiskApy);

        mockPendle = new MockPendleMarket(USDC_ADDRESS, address(ptToken), address(ytToken), highRiskApy);
        console.log("MockPendleMarket deployed with APY:", highRiskApy);

        console.log("\n=== Deploying Pool Strategies ===");
        aaveStrategy = new AaveStrategy(USDC_ADDRESS, address(mockAave));
        pendleStrategy = new PendleStrategy(USDC_ADDRESS, address(mockPendle));

        console.log("\n=== Deploying Core Risk Routers ===");
        vault = new Vault(USDC_ADDRESS, DEPLOYER_ADMIN_ADDRESS);

        lowRiskStrategy = new LowRiskStrategy(USDC_ADDRESS, address(vault));
        highRiskStrategy = new HighRiskStrategy(USDC_ADDRESS, address(vault));

        console.log("\n=== Deploying Strategy Manager ===");
        strategyManager = new StrategyManager(
            address(lowRiskStrategy),
            address(highRiskStrategy),
            DEPLOYER_ADMIN_ADDRESS
        );

        console.log("\n=== Wiring System ===");
        vault.setApprovedStrategy(address(lowRiskStrategy), true);
        vault.setApprovedStrategy(address(highRiskStrategy), true);
        vault.setChainlinkAdmin(CHAINLINK_AUTOMATION_ADMIN_ADDRESS);

        lowRiskStrategy.setActivePool(address(aaveStrategy));
        highRiskStrategy.setActivePool(address(pendleStrategy));

        console.log("\n=== Deployment Summary ===");
        console.log("Vault:            ", address(vault));
        console.log("StrategyManager:  ", address(strategyManager));
        console.log("LowRiskStrategy:  ", address(lowRiskStrategy));
        console.log("HighRiskStrategy: ", address(highRiskStrategy));
        console.log("AaveStrategy:     ", address(aaveStrategy));
        console.log("PendleStrategy:   ", address(pendleStrategy));
        console.log("MockAavePool:     ", address(mockAave));
        console.log("MockPendleMarket: ", address(mockPendle));
        console.log("USDC:             ", USDC_ADDRESS);

        vm.stopBroadcast();
    }
}
