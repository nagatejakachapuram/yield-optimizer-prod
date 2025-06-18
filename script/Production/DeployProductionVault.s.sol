// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../../src/Contracts/Vault.sol";
import "../../src/Contracts/StrategyManager.sol";
import "../../src/Strategies/LowRiskStrategy.sol"; 
import "../../src/Strategies/HighRiskStrategy.sol"; 
import "../../src/Strategies/Strategy_Pools/AaveStrategyPool.sol"; 
import "../../src/Strategies/Strategy_Pools/PendleStrategy.sol"; 

// OpenZeppelin Interfaces for tokens
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// --- REAL SEPOLIA TESTNET ADDRESSES ---
// These are the official and verified contract addresses for Sepolia.

// Official Testnet USDC (from Circle Faucet: https://faucet.circle.com/)
address constant USDC_ADDRESS = 0x1c7D4B196cb0c7b01D743928b76Bbc59EBa05B0F; 

// Aave V3 Pool address on Sepolia (official Aave deployment)
address constant AAVE_POOL_ADDRESS = 0xC13E21b648a5ee794902342038Ff3aaB8f6f8C7b; 

// Pendle Router address on Sepolia (official Pendle deployment)
address constant PENDLE_ROUTER_ADDRESS = 0x87d6052b7e4e1a61d4c6e3d0b0c0E3C0F9F3e4E4; 

// Uniswap V2 Router02 on Sepolia (a common DEX router for token swaps)
// Note: For USDY-USDC swaps, you would need to ensure a USDY token and a
// liquid USDY-USDC pair actually exist on this router on Sepolia.
// If USDY is not available, USDY_ADDRESS would still need to be a mock.
// address constant UNISWAP_V2_ROUTER_ADDRESS = 0xeE567Fe1712Faf6149d80dA1E6934E354124CfE3;

// --- USDY Token Address on Sepolia ---
// As of now, an official, liquid USDY token might not be widely available on Sepolia's public DEXes.
// You will likely still need to:
// 1. Deploy your own MockUSDY.sol contract to Sepolia.
// 2. Set this USDY_ADDRESS constant to the address of your deployed MockUSDY.
// If you find an official USDY on Sepolia with liquidity, use its address instead.
// address constant USDY_ADDRESS = 0xYourDeployedMockUSDYAddressHere; // <-- MOST LIKELY STILL A MOCK!

// --- Admin & Automation Addresses ---
// This should be your test wallet address or a dedicated admin address for the demo.
address constant DEPLOYER_ADMIN_ADDRESS = 0x05e62059FEDa53EA732889602D0F777Af1a66386;
// This can be the same as DEPLOYER_ADMIN_ADDRESS for a demo.
address constant CHAINLINK_AUTOMATION_ADMIN_ADDRESS = 0x05e62059FEDa53EA732889602D0F777Af1a66386;


contract DeployProductionVault is Script {
    function run()
        public
        returns (
            Vault vault,
            StrategyManager strategyManager,
            LowRiskStrategy lowRiskStrategyRouter,
            HighRiskStrategy highRiskStrategyRouter,
            AaveStrategy aaveStrategy,
            PendleStrategy pendleStrategy
        )
    {
        // 1. Start Broadcast (Ensure your private key is configured for Forge)
        // Make sure the deployer's address has enough ETH on Sepolia for gas fees.
        vm.startBroadcast();

        // --- 1. Deploy Core Strategy Pools (Connecting to Real Testnet Protocols) ---
        // Your custom strategies will use the real Sepolia USDC and interact with
        // the official Aave and Pendle contracts on Sepolia.
        console.log("--- Deploying Core Strategy Pools ---");

        console.log("Deploying AaveStrategy (using Sepolia USDC and real Aave pool)...");
        aaveStrategy = new AaveStrategy(USDC_ADDRESS, AAVE_POOL_ADDRESS);
        console.log("AaveStrategy deployed at:", address(aaveStrategy));

        console.log("Deploying PendleStrategy (using Sepolia USDC and real Pendle router)...");
        pendleStrategy = new PendleStrategy(USDC_ADDRESS, PENDLE_ROUTER_ADDRESS);
        console.log("PendleStrategy deployed at:", address(pendleStrategy));

        // --- 2. Deploy Router Strategies (LowRisk and HighRisk) ---
        // These router strategies manage allocation based on risk, using Sepolia USDC.
        console.log("\n--- Deploying Router Strategies ---");

        console.log("Deploying LowRiskStrategyRouter (managing Sepolia USDC)...");
        lowRiskStrategyRouter = new LowRiskStrategy(USDC_ADDRESS);
        console.log("LowRiskStrategyRouter deployed at:", address(lowRiskStrategyRouter));

        console.log("Deploying HighRiskStrategyRouter (managing Sepolia USDC)...");
        highRiskStrategyRouter = new HighRiskStrategy(USDC_ADDRESS);
        console.log("HighRiskStrategyRouter deployed at:", address(highRiskStrategyRouter));

        // --- 3. Deploy Main Vault Contract ---
        // The Vault will handle deposits of Sepolia USDC and (likely mock) USDY.
        // It will attempt to use the real Uniswap V2 Router for USDY swaps.
        console.log("\n--- Deploying Main Vault Contract ---");

        console.log("Deploying Vault...");
        vault = new Vault(
            USDC_ADDRESS,
            DEPLOYER_ADMIN_ADDRESS
        );
        console.log("Vault deployed at:", address(vault));

        // --- 4. Deploy Strategy Manager ---
        // This contract manages user risk preferences and directs to the router strategies.
        console.log("\n--- Deploying StrategyManager ---");

        strategyManager = new StrategyManager(
            address(lowRiskStrategyRouter),
            address(highRiskStrategyRouter),
            DEPLOYER_ADMIN_ADDRESS
        );
        console.log("StrategyManager deployed at:", address(strategyManager));

        // --- 5. Post-Deployment Configuration (Admin Calls) ---
        // Crucial steps to link contracts and set up roles after deployment.
        console.log("\n--- Starting Post-Deployment Configuration (Admin Calls) ---");

        // Vault Configuration: Approve router strategies
        console.log("Configuring Vault: Approving Router Strategies...");
        vault.setApprovedStrategy(address(lowRiskStrategyRouter), true);
        console.log("Approved LowRiskStrategyRouter in Vault:", address(lowRiskStrategyRouter));
        vault.setApprovedStrategy(address(highRiskStrategyRouter), true);
        console.log("Approved HighRiskStrategyRouter in Vault:", address(highRiskStrategyRouter));

        // Set the Chainlink Automation Admin in the Vault
        vault.setChainlinkAdmin(CHAINLINK_AUTOMATION_ADMIN_ADDRESS);
        console.log("Set Chainlink Admin in Vault to:", CHAINLINK_AUTOMATION_ADMIN_ADDRESS);

        // Router Strategy Configuration (linking to concrete strategies)
        console.log("Configuring Router Strategies...");
        lowRiskStrategyRouter.setActivePool(address(aaveStrategy));
        console.log("LowRiskStrategyRouter activePool set to AaveStrategy:", address(aaveStrategy));

        highRiskStrategyRouter.setActivePool(address(pendleStrategy));
        console.log("HighRiskStrategyRouter activePool set to PendleStrategy:", address(pendleStrategy));
        
        // --- 6. Final Steps ---
        console.log("\n--- Real Sepolia Testnet Deployment Complete! ---");
        console.log("----------------------------------------------------\n");
        console.log("Deployed Contracts:");
        console.log("  Vault Address:           ", address(vault));
        console.log("  StrategyManager Address: ", address(strategyManager));
        console.log("  LowRiskStrategyRouter:   ", address(lowRiskStrategyRouter));
        console.log("  HighRiskStrategyRouter:  ", address(highRiskStrategyRouter));
        console.log("  AaveStrategy (Concrete): ", address(aaveStrategy));
        console.log("  PendleStrategy (Concrete):", address(pendleStrategy));
        console.log("\nExternal Sepolia Testnet Dependencies Used:");
        console.log("  USDC Address (Sepolia):  ", USDC_ADDRESS);
        console.log("  Aave Pool Address:       ", AAVE_POOL_ADDRESS);
        console.log("  Pendle Router Address:   ", PENDLE_ROUTER_ADDRESS);
        console.log("\nAdmin/Automation Roles:");
        console.log("  Deployer/Admin Address:  ", DEPLOYER_ADMIN_ADDRESS);
        console.log("  Chainlink Automation Admin:", CHAINLINK_AUTOMATION_ADMIN_ADDRESS);
        console.log("----------------------------------------------------\n");

        vm.stopBroadcast();
    }
}