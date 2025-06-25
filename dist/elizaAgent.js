"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ElizaOS = void 0;
const ethers_1 = require("ethers");
const axios_1 = __importDefault(require("axios"));
const dotenv = __importStar(require("dotenv"));
dotenv.config();
// Constants
const VAULT_ADDRESS = process.env.VAULT_ADDRESS;
const STRATEGY_MANAGER_ADDRESS = process.env.STRATEGY_MANAGER_ADDRESS;
const RPC_URL = process.env.SEPOLIA_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
// Placeholder for strategy addresses - REPLACE WITH ACTUAL DEPLOYED MockStrategy ADDRESSES
// These will be the addresses of your lowRiskStrategy and highRiskStrategy MockStrategy contracts
const DEPLOYED_STRATEGY_CONTRACT_ADDRESSES = {
    // You MUST replace these with the actual deployed addresses after running DeployAllContracts.s.sol
    // from your previous script execution output.
    'low': '0x4248d8d1a47d7dF637742f22cB789e942143F8BB', // Example: Replace with actual lowRiskStrategy address
    'high': '0x0108b9bc01D9e372f01Db5454eeC5423B72f1833', // Example: Replace with actual highRiskStrategy address
};
// Simplified mapping of DeFiLlama protocols to our risk categories (low/high)
// In a real system, this would be determined by a more complex risk assessment.
const PROTOCOL_RISK_CLASSIFICATION = {
    'compound': 'low', // Example: Assume Compound is generally low risk
    'aave': 'low', // Example: Assume Aave is generally low risk
    'uniswap': 'high', // Example: Assume Uniswap LPs can be high risk due to impermanent loss
    'aerodrome-slipstream': 'high', // Example: High risk
    'lido': 'low', // Example: Lido staking is generally low risk
    'makerdao': 'low', // Example: MakerDAO is generally low risk
    // Add more protocols and their risk classifications as needed
};
// Validate environment variables
if (!VAULT_ADDRESS)
    throw new Error('VAULT_ADDRESS environment variable is not set');
if (!STRATEGY_MANAGER_ADDRESS)
    throw new Error('STRATEGY_MANAGER_ADDRESS environment variable is not set');
if (!RPC_URL)
    throw new Error('SEPOLIA_RPC_URL environment variable is not set');
if (!PRIVATE_KEY)
    throw new Error('PRIVATE_KEY environment variable is not set');
if (!DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.low || !DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.high) {
    console.warn("WARNING: DEPLOYED_STRATEGY_CONTRACT_ADDRESSES are placeholders. Please update them with actual deployed addresses.");
}
// Initialize provider and signer
const provider = new ethers_1.ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers_1.ethers.Wallet(PRIVATE_KEY, provider);
// Vault ABI - only the functions we need
const VAULT_ABI = [
    "function setApprovedStrategy(address strategy, bool approved) external",
    "function getTotalValueLocked() external view returns (uint256)",
    "function userDeposits(address) external view returns (uint256)",
    "function allocateFunds(address user, uint256 amount, address strategy) external"
];
// StrategyManager ABI - only the functions we need
const STRATEGY_MANAGER_ABI = [
    "function lowRiskStrategy() external view returns (address)",
    "function highRiskStrategy() external view returns (address)",
    "function setUserStrategy(address strategy) external",
    "function getUserStrategy(address user) external view returns (address)"
];
// Initialize contracts with error handling
let vaultContract;
let strategyManagerContract;
try {
    vaultContract = new ethers_1.ethers.Contract(VAULT_ADDRESS, VAULT_ABI, wallet);
    strategyManagerContract = new ethers_1.ethers.Contract(STRATEGY_MANAGER_ADDRESS, STRATEGY_MANAGER_ABI, wallet);
}
catch (error) {
    console.error('Error initializing contracts:', error);
    throw new Error('Failed to initialize contracts. Check addresses and network config.');
}
class ElizaOS {
    constructor() {
        this.marketData = null;
    }
    /**
     * Fetches market data from various DeFi APIs
     */
    async fetchMarketData() {
        console.log('Fetching market data...');
        try {
            const [defillamaData] = await Promise.all([
                this.fetchDefiLlamaData()
                // You can add Coingecko or other price feeds here if needed
                // this.fetchCoingeckoData(),
            ]);
            this.marketData = {
                timestamp: Date.now(),
                yields: {}, // Initialize yields object
                prices: {}, // Initialize prices object
            };
            // Process DeFiLlama data and apply risk classification
            if (defillamaData.yields) {
                for (const protocol in defillamaData.yields) {
                    const data = defillamaData.yields[protocol];
                    const riskCategory = PROTOCOL_RISK_CLASSIFICATION[protocol]; // Get risk category
                    if (riskCategory) { // Only include if we have a classification
                        this.marketData.yields[protocol] = {
                            apy: data.apy,
                            tvl: data.tvl,
                            risk: data.risk,
                            // You might want to store the riskCategory here too if needed later
                        };
                    }
                }
            }
            if (!this.marketData || Object.keys(this.marketData.yields).length === 0) {
                throw new Error('Failed to initialize market data or no relevant yields found.');
            }
            console.log('Market data fetched successfully. Yields:', this.marketData.yields);
            return this.marketData;
        }
        catch (error) {
            console.error('Error fetching market data:', error);
            throw error;
        }
    }
    /**
     * Fetches data from Coingecko API (optional, if you need token prices)
     */
    async fetchCoingeckoData() {
        try {
            const response = await axios_1.default.get('https://api.coingecko.com/api/v3/simple/price', {
                params: {
                    ids: 'usd-coin,ethereum',
                    vs_currencies: 'usd'
                }
            });
            return { prices: response.data };
        }
        catch (error) {
            console.error('Error fetching Coingecko data:', error);
            return { prices: {} };
        }
    }
    /**
     * Fetches data from DeFiLlama API
     */
    async fetchDefiLlamaData() {
        try {
            const response = await axios_1.default.get('https://yields.llama.fi/pools');
            // Process and format the yield data
            const yields = response.data.data.reduce((acc, pool) => {
                // Filter for active pools with APY > 0
                if (pool.status === 'active' && pool.apy > 0) {
                    acc[pool.project] = {
                        apy: pool.apy,
                        tvl: pool.tvlUsd,
                        risk: this.calculateRiskScore(pool) // Use agent's risk calc
                    };
                }
                return acc;
            }, {});
            return { yields };
        }
        catch (error) {
            console.error('Error fetching DeFiLlama data:', error);
            return { yields: {} };
        }
    }
    /**
     * Calculates risk score for a protocol (0-100) - Placeholder heuristic
     */
    calculateRiskScore(pool) {
        // More sophisticated logic would go here. For now, a simplified random score.
        // Or you can map based on protocol, e.g., low for Aave/Compound, high for volatile LPs.
        // For demonstration, let's use a very basic heuristic:
        // Lower TVL might imply higher risk for very small pools, but high TVL doesn't mean no risk.
        // Here, we just use a random value as a placeholder.
        return Math.floor(Math.random() * 100);
    }
    /**
     * Determines the best specific DeFi pool strategy based on the user's chosen risk level.
     * @param userPreferredStrategyAddress The address of the MockStrategy chosen by the user (lowRiskStrategy or highRiskStrategy).
     * @returns The selected StrategyInfo for allocation.
     */
    async determineOptimalDefiPool(userPreferredStrategyAddress) {
        if (!this.marketData) {
            throw new Error('Market data not fetched. Call fetchMarketData() first.');
        }
        console.log('Determining optimal DeFi pool based on user preference...');
        let targetRiskCategory = null;
        // Determine the target risk category based on the user's chosen MockStrategy address
        if (userPreferredStrategyAddress === DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.low) {
            targetRiskCategory = 'low';
        }
        else if (userPreferredStrategyAddress === DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.high) {
            targetRiskCategory = 'high';
        }
        else {
            throw new Error(`User preferred strategy address ${userPreferredStrategyAddress} does not match any known low/high risk strategy contracts.`);
        }
        console.log(`User selected ${targetRiskCategory} risk profile.`);
        const availableProtocols = [];
        // Filter market data based on the target risk category
        for (const protocol in this.marketData.yields) {
            const data = this.marketData.yields[protocol];
            if (PROTOCOL_RISK_CLASSIFICATION[protocol] === targetRiskCategory) {
                availableProtocols.push({
                    id: this.generateStrategyId(protocol),
                    protocol,
                    expectedApy: data.apy,
                    risk: data.risk,
                    allocation: this.calculateAllocation(data, BigInt(0)), // TVL not directly used for allocation here, just placeholder
                    riskCategory: targetRiskCategory
                });
            }
        }
        if (availableProtocols.length === 0) {
            throw new Error(`No active ${targetRiskCategory} risk DeFi pools found matching classification.`);
        }
        // Sort by APY (highest first) within the chosen risk category
        availableProtocols.sort((a, b) => b.expectedApy - a.expectedApy);
        const bestPool = availableProtocols[0];
        console.log(`Best DeFi pool for ${targetRiskCategory} risk found:`, bestPool);
        return bestPool;
    }
    /**
     * Generates a unique strategy ID based on protocol name
     */
    generateStrategyId(protocol) {
        const hash = ethers_1.ethers.keccak256(ethers_1.ethers.toUtf8Bytes(protocol));
        return parseInt(hash.slice(2, 10), 16); // Convert first 4 bytes (8 hex chars) of hash to number
    }
    /**
     * Calculates allocation percentage based on risk and TVL (Placeholder)
     * This logic is more relevant if the agent itself is deciding allocation *within* a strategy.
     * For now, it's simplified.
     */
    calculateAllocation(data, tvl) {
        return Math.min(100, Math.max(0, 100 - data.risk)); // Example: Allocate less for higher risk
    }
    /**
     * Calls Vault's allocateFunds function to move user's funds to the selected strategy.
     * @param userAddress The user whose funds are being allocated.
     * @param amount The amount to allocate.
     * @param targetMockStrategyAddress The address of the specific MockStrategy (low or high risk) to allocate to.
     */
    async callAllocateFunds(userAddress, amount, targetMockStrategyAddress) {
        console.log(`Agent initiating allocation of ${ethers_1.ethers.formatUnits(amount, 6)} USDC from ${userAddress} to strategy ${targetMockStrategyAddress}...`);
        try {
            // First, ensure the target strategy is approved by the Vault (this should be done during setup/admin)
            // This is just a safeguard; in a real flow, the admin would approve all valid strategies initially.
            // await vaultContract.setApprovedStrategy(targetMockStrategyAddress, true); // If not already approved
            const tx = await vaultContract.allocateFunds(userAddress, amount, targetMockStrategyAddress);
            console.log('AllocateFunds transaction sent, hash:', tx.hash);
            await tx.wait();
            console.log('AllocateFunds transaction mined successfully.');
        }
        catch (error) {
            console.error('Error calling allocateFunds:', error);
            throw error;
        }
    }
}
exports.ElizaOS = ElizaOS;
// --- Main Execution Loop ---
async function main() {
    console.log('ElizaOS agent starting its optimization cycle...');
    const elizaOS = new ElizaOS();
    const user = wallet.address; // The address of the account running this script, acting as the user/admin
    try {
        // 1. Fetch Market Data
        await elizaOS.fetchMarketData();
        // --- Simulate User Interaction (Setting Preference and Depositing) ---
        // These are typically done by a user via a frontend, but simulated here for the full flow.
        // Mint tokens to the user (wallet.address) for deposit
        // In a real scenario, this would be an actual token transfer to the user
        // For testing, MockUSDC/USDY must have a mint function
        console.log(`Minting 1000 USDC and 1000 USDY to ${user} for simulation...`);
        // Assumes MockUSDC and MockUSDY are deployed and accessible here.
        // We need to get the MockUSDC and MockUSDY contract instances first.
        const mockUsdcAbi = ["function mint(address to, uint256 amount) public"];
        const mockUsdyAbi = ["function mint(address to, uint256 amount) public"];
        const usdcContract = new ethers_1.ethers.Contract(process.env.USDC_ADDRESS, mockUsdcAbi, wallet);
        const usdyContract = new ethers_1.ethers.Contract(process.env.USDY_ADDRESS, mockUsdyAbi, wallet);
        // Ensure the minter is the owner of MockUSDC/USDY for minting to work
        // This requires you to ensure the private key running this script
        // is the owner of your MockUSDC/USDY contracts from DeployAllContracts.s.sol
        // (which it is, if it's the deployer)
        if (usdcContract.runner && 'owner' in usdcContract.runner && await usdcContract.owner() === wallet.address) { // Check if owner() exists
            await usdcContract.mint(user, ethers_1.ethers.parseUnits('1000', 6));
        }
        else {
            console.warn("WARNING: Skipping MockUSDC mint to user. Ensure script's PRIVATE_KEY is owner of MockUSDC or handle minting externally.");
            // If not owner, you'd have to use vm.deal in a test environment or ensure tokens are pre-minted.
        }
        if (usdyContract.runner && 'owner' in usdyContract.runner && await usdyContract.owner() === wallet.address) { // Check if owner() exists
            await usdyContract.mint(user, ethers_1.ethers.parseUnits('1000', 18));
        }
        else {
            console.warn("WARNING: Skipping MockUSDY mint to user. Ensure script's PRIVATE_KEY is owner of MockUSDY or handle minting externally.");
        }
        console.log(`User ${user} USDC balance:`, ethers_1.ethers.formatUnits(await usdcContract.balanceOf(user), 6));
        console.log(`User ${user} USDY balance:`, ethers_1.ethers.formatUnits(await usdyContract.balanceOf(user), 18));
        // User selects a strategy preference (e.g., low risk)
        console.log('User setting low risk strategy preference...');
        const lowRiskStrategyAddress = DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.low;
        await strategyManagerContract.setUserStrategy(lowRiskStrategyAddress);
        console.log(`User's preferred strategy set to: ${await strategyManagerContract.getUserStrategy(user)}`);
        // User deposits into the Vault
        console.log('User depositing 500 USDC into Vault...');
        const depositAmount = ethers_1.ethers.parseUnits('500', 6);
        await usdcContract.approve(VAULT_ADDRESS, depositAmount); // User approves Vault
        await vaultContract.deposit(depositAmount);
        console.log(`User's Vault deposit: ${ethers_1.ethers.formatUnits(await vaultContract.userDeposits(user), 6)} USDC`);
        // --- ElizaOS Agent's Core Logic (Post-User Actions) ---
        // Agent retrieves user's preferred strategy from StrategyManager
        const userPreferredStrategyFromManager = await strategyManagerContract.getUserStrategy(user);
        console.log(`Agent retrieved user's preferred strategy from manager: ${userPreferredStrategyFromManager}`);
        // Agent determines the optimal DeFi pool for this user's risk profile
        const bestDefiPool = await elizaOS.determineOptimalDefiPool(userPreferredStrategyFromManager);
        console.log('Agent recommends depositing into protocol:', bestDefiPool.protocol, 'with APY:', bestDefiPool.expectedApy);
        // Agent then allocates the user's funds from the Vault to the *corresponding MockStrategy*
        // The MockStrategy (lowRiskStrategy or highRiskStrategy) is the actual on-chain destination.
        const currentVaultDeposit = await vaultContract.userDeposits(user);
        if (currentVaultDeposit > 0) {
            console.log("Current user vault deposit is:", ethers_1.ethers.formatUnits(currentVaultDeposit, 6), "USDC");
            // Determine which MockStrategy address corresponds to the bestDefiPool's risk category
            let targetMockStrategyAddress;
            if (bestDefiPool.riskCategory === 'low') {
                targetMockStrategyAddress = DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.low;
            }
            else if (bestDefiPool.riskCategory === 'high') {
                targetMockStrategyAddress = DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.high;
            }
            else {
                throw new Error("Invalid risk category determined by agent.");
            }
            await elizaOS.callAllocateFunds(user, currentVaultDeposit, targetMockStrategyAddress);
        }
        else {
            console.log("No funds in Vault to allocate after deposit simulation.");
        }
        console.log('ElizaOS agent cycle completed successfully.');
    }
    catch (error) {
        console.error('ElizaOS agent encountered an error:', error);
    }
}
// Constants for MockUSDC/USDY addresses are needed for minting
// You should add these to your .env file or fetch them from the deployment output
// For this script, we'll assume they are available via process.env.
// This is a common practice for scripts interacting with known deployed contracts.
if (!process.env.USDC_ADDRESS)
    throw new Error('USDC_ADDRESS environment variable is not set');
if (!process.env.USDY_ADDRESS)
    throw new Error('USDY_ADDRESS environment variable is not set');
main().catch(console.error);
