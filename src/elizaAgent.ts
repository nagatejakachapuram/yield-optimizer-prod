import { ethers } from 'ethers';
import axios from 'axios';
import * as dotenv from 'dotenv';

dotenv.config();

// Types
interface MarketData {
    timestamp: number;
    yields: {
        [protocol: string]: {
            apy: number;
            tvl: number;
            risk: number; // Risk score (0-100) as determined by our agent's heuristic
        };
    };
    prices: {
        [token: string]: number;
    };
}

interface StrategyInfo { // Renamed from 'Strategy' to avoid confusion with on-chain contracts
    id: number; // A unique ID for the specific protocol/pool
    protocol: string; // e.g., 'aave', 'compound'
    expectedApy: number;
    risk: number;
    allocation: number; // Placeholder for potential allocation percentage
    riskCategory: 'low' | 'high'; // New: Categorization of the protocol's risk profile
}

// Contract interfaces
interface VaultContract extends ethers.BaseContract {
    setApprovedStrategy: (strategyAddress: string, approved: boolean) => Promise<ethers.ContractTransactionResponse>;
    getTotalValueLocked: () => Promise<bigint>;
    userDeposits: (userAddress: string) => Promise<bigint>;
    allocateFunds: (user: string, amount: bigint, strategy: string) => Promise<ethers.ContractTransactionResponse>;
    // FIX: Added deposit, withdraw, and swapUSDYtoUSDC to the interface
    deposit: (amount: bigint) => Promise<ethers.ContractTransactionResponse>;
    withdraw: (amount: bigint) => Promise<ethers.ContractTransactionResponse>;
    swapUSDYtoUSDC: (amount: bigint) => Promise<ethers.ContractTransactionResponse>;
}

interface StrategyManagerContract extends ethers.BaseContract {
    lowRiskStrategy(): Promise<string>;
    highRiskStrategy(): Promise<string>;
    setUserStrategy(strategyAddress: string): Promise<ethers.ContractTransactionResponse>;
    getUserStrategy(userAddress: string): Promise<string>;
}

interface MockERC20Contract extends ethers.BaseContract {
    mint: (to: string, amount: bigint) => Promise<ethers.ContractTransactionResponse>;
    approve: (spender: string, amount: bigint) => Promise<ethers.ContractTransactionResponse>;
    balanceOf: (account: string) => Promise<bigint>;
    owner(): Promise<string>; 
}


// Constants
const VAULT_ADDRESS = process.env.VAULT_ADDRESS as string;
const STRATEGY_MANAGER_ADDRESS = process.env.STRATEGY_MANAGER_ADDRESS as string;
const RPC_URL = process.env.SEPOLIA_RPC_URL as string;
const PRIVATE_KEY = process.env.PRIVATE_KEY as string;
const USDC_ADDRESS = process.env.USDC_ADDRESS as string; 
const USDY_ADDRESS = process.env.USDY_ADDRESS as string; 


// Placeholder for strategy addresses - REPLACE WITH ACTUAL DEPLOYED MockStrategy ADDRESSES
const DEPLOYED_STRATEGY_CONTRACT_ADDRESSES: { low: string; high: string } = {
    // You MUST replace these with the actual deployed addresses after running DeployAllContracts.s.sol
    // from your previous script execution output.
    'low': process.env.LOW_RISK_STRATEGY_ADDRESS as string, // Get from .env
    'high': process.env.HIGH_RISK_STRATEGY_ADDRESS as string, // Get from .env
};

// Simplified mapping of DeFiLlama protocols to our risk categories (low/high)
const PROTOCOL_RISK_CLASSIFICATION: { [protocol: string]: 'low' | 'high' } = {
    'compound': 'low',
    'aave': 'low',
    'lido': 'low',
    'makerdao': 'low',
    'uniswap': 'high',
    'aerodrome-slipstream': 'high',
    // Add more protocols and their risk classifications as needed
};

// Validate environment variables
if (!VAULT_ADDRESS) throw new Error('VAULT_ADDRESS environment variable is not set');
if (!STRATEGY_MANAGER_ADDRESS) throw new Error('STRATEGY_MANAGER_ADDRESS environment variable is not set');
if (!RPC_URL) throw new Error('SEPOLIA_RPC_URL environment variable is not set');
if (!PRIVATE_KEY) throw new Error('PRIVATE_KEY environment variable is not set');
if (!USDC_ADDRESS) throw new Error('USDC_ADDRESS environment variable is not set');
if (!USDY_ADDRESS) throw new Error('USDY_ADDRESS environment variable is not set');
if (!DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.low) throw new Error('LOW_RISK_STRATEGY_ADDRESS environment variable is not set');
if (!DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.high) throw new Error('HIGH_RISK_STRATEGY_ADDRESS environment variable is not set');


// Initialize provider and signer
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Vault ABI - only the functions we need
const VAULT_ABI = [
    "function setApprovedStrategy(address strategy, bool approved) external",
    "function getTotalValueLocked() external view returns (uint256)",
    "function userDeposits(address) external view returns (uint256)",
    "function allocateFunds(address user, uint256 amount, address strategy) external",
    // FIX: Added deposit, withdraw, and swapUSDYtoUSDC to the ABI
    "function deposit(uint256 amount) external",
    "function withdraw(uint256 amount) external",
    "function swapUSDYtoUSDC(uint256 amount) external"
];

// StrategyManager ABI - only the functions we need
const STRATEGY_MANAGER_ABI = [
    "function lowRiskStrategy() external view returns (address)",
    "function highRiskStrategy() external view returns (address)",
    "function setUserStrategy(address strategy) external",
    "function getUserStrategy(address user) external view returns (address)"
];

// Mock ERC20 ABIs for basic token interaction
const MOCK_ERC20_ABI = [
    "function mint(address to, uint256 amount) public",
    "function approve(address spender, uint256 amount) public returns (bool)",
    "function balanceOf(address account) public view returns (uint256)",
    "function owner() public view returns (address)" // Assuming MockERC20 has an owner function
];

// Initialize contracts with error handling
let vaultContract: VaultContract;
let strategyManagerContract: StrategyManagerContract;
let usdcContract: MockERC20Contract;
let usdyContract: MockERC20Contract;

try {
    vaultContract = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, wallet) as unknown as VaultContract;
    strategyManagerContract = new ethers.Contract(STRATEGY_MANAGER_ADDRESS, STRATEGY_MANAGER_ABI, wallet) as unknown as StrategyManagerContract;
    usdcContract = new ethers.Contract(USDC_ADDRESS, MOCK_ERC20_ABI, wallet) as unknown as MockERC20Contract;
    usdyContract = new ethers.Contract(USDY_ADDRESS, MOCK_ERC20_ABI, wallet) as unknown as MockERC20Contract;
} catch (error) {
    console.error('Error initializing contracts:', error);
    throw new Error('Failed to initialize contracts. Check addresses and network config.');
}

class ElizaOS {
    private marketData: MarketData | null = null;

    /**
     * Fetches market data from various DeFi APIs
     */
    async fetchMarketData(): Promise<MarketData> {
        console.log('Fetching market data...');
        try {
            const [defillamaData] = await Promise.all([
                this.fetchDefiLlamaData()
            ]);

            this.marketData = {
                timestamp: Date.now(),
                yields: {},
                prices: {},
            };

            if (defillamaData.yields) {
                for (const protocol in defillamaData.yields) {
                    const data = defillamaData.yields[protocol];
                    const riskCategory = PROTOCOL_RISK_CLASSIFICATION[protocol];
                    if (riskCategory) {
                        this.marketData.yields[protocol] = {
                            apy: data.apy,
                            tvl: data.tvl,
                            risk: data.risk,
                        };
                    }
                }
            }

            if (!this.marketData || Object.keys(this.marketData.yields).length === 0) {
                throw new Error('Failed to initialize market data or no relevant yields found.');
            }
            console.log('Market data fetched successfully. Yields:', this.marketData.yields);
            return this.marketData;
        } catch (error) {
            console.error('Error fetching market data:', error);
            throw error;
        }
    }

    /**
     * Fetches data from Coingecko API (optional, if you need token prices)
     */
    private async fetchCoingeckoData(): Promise<Partial<MarketData>> {
        try {
            const response = await axios.get('https://api.coingecko.com/api/v3/simple/price', {
                params: {
                    ids: 'usd-coin,ethereum',
                    vs_currencies: 'usd'
                }
            });
            return { prices: response.data as { [token: string]: number } };
        } catch (error) {
            console.error('Error fetching Coingecko data:', error);
            return { prices: {} };
        }
    }

    /**
     * Fetches data from DeFiLlama API
     */
    private async fetchDefiLlamaData(): Promise<Partial<MarketData>> {
        try {
            const response = await axios.get('https://yields.llama.fi/pools');
            
            const yields = response.data.data.reduce((acc: { [key: string]: any }, pool: any) => {
                if (pool.status === 'active' && pool.apy > 0) {
                    acc[pool.project] = {
                        apy: pool.apy,
                        tvl: pool.tvlUsd,
                        risk: this.calculateRiskScore(pool)
                    };
                }
                return acc;
            }, {});

            return { yields };
        } catch (error) {
            console.error('Error fetching DeFiLlama data:', error);
            return { yields: {} };
        }
    }

    /**
     * Calculates risk score for a protocol (0-100) - Placeholder heuristic
     */
    private calculateRiskScore(pool: any): number {
        // More sophisticated logic would go here. For now, a simplified random score.
        return Math.floor(Math.random() * 100); 
    }

    /**
     * Determines the best specific DeFi pool strategy based on the user's chosen risk level.
     * @param userPreferredStrategyAddress The address of the MockStrategy chosen by the user (lowRiskStrategy or highRiskStrategy).
     * @returns The selected StrategyInfo for allocation.
     */
    async determineOptimalDefiPool(userPreferredStrategyAddress: string): Promise<StrategyInfo> {
        if (!this.marketData) {
            throw new Error('Market data not fetched. Call fetchMarketData() first.');
        }

        console.log('Determining optimal DeFi pool based on user preference...');
        
        let targetRiskCategory: 'low' | 'high' | null = null;

        if (userPreferredStrategyAddress === DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.low) {
            targetRiskCategory = 'low';
        } else if (userPreferredStrategyAddress === DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.high) {
            targetRiskCategory = 'high';
        } else {
            throw new Error(`User preferred strategy address ${userPreferredStrategyAddress} does not match any known low/high risk strategy contracts.`);
        }

        console.log(`User selected ${targetRiskCategory} risk profile.`);

        const availableProtocols: StrategyInfo[] = [];

        for (const protocol in this.marketData.yields) {
            const data = this.marketData.yields[protocol];
            if (PROTOCOL_RISK_CLASSIFICATION[protocol] === targetRiskCategory) {
                 availableProtocols.push({
                    id: this.generateStrategyId(protocol),
                    protocol,
                    expectedApy: data.apy,
                    risk: data.risk,
                    allocation: this.calculateAllocation(data, BigInt(0)),
                    riskCategory: targetRiskCategory
                });
            }
        }

        if (availableProtocols.length === 0) {
            throw new Error(`No active ${targetRiskCategory} risk DeFi pools found matching classification.`);
        }

        availableProtocols.sort((a, b) => b.expectedApy - a.expectedApy);

        const bestPool = availableProtocols[0];
        console.log(`Best DeFi pool for ${targetRiskCategory} risk found:`, bestPool);
        return bestPool;
    }

    /**
     * Generates a unique strategy ID based on protocol name
     */
    private generateStrategyId(protocol: string): number {
        const hash = ethers.keccak256(ethers.toUtf8Bytes(protocol));
        return parseInt(hash.slice(2, 10), 16);
    }

    /**
     * Calculates allocation percentage based on risk and TVL (Placeholder)
     */
    private calculateAllocation(data: any, tvl: bigint): number {
        return Math.min(100, Math.max(0, 100 - data.risk));
    }

    /**
     * Calls Vault's allocateFunds function to move user's funds to the selected strategy.
     * @param userAddress The user whose funds are being allocated.
     * @param amount The amount to allocate.
     * @param targetMockStrategyAddress The address of the specific MockStrategy (low or high risk) to allocate to.
     */
    async callAllocateFunds(userAddress: string, amount: bigint, targetMockStrategyAddress: string): Promise<void> {
        console.log(`Agent initiating allocation of ${ethers.formatUnits(amount, 6)} USDC from ${userAddress} to strategy ${targetMockStrategyAddress}...`);
        try {
            const tx = await vaultContract.allocateFunds(userAddress, amount, targetMockStrategyAddress);
            console.log('AllocateFunds transaction sent, hash:', tx.hash);
            await tx.wait();
            console.log('AllocateFunds transaction mined successfully.');
        } catch (error) {
            console.error('Error calling allocateFunds:', error);
            throw error;
        }
    }
}

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
        console.log(`Minting 1000 USDC and 1000 USDY to ${user} for simulation...`);
        
        // Check if wallet is owner of MockUSDC for minting
        const usdcOwner = await usdcContract.owner();
        if (usdcOwner.toLowerCase() === wallet.address.toLowerCase()) {
             const mintTxUsdc = await usdcContract.mint(user, ethers.parseUnits('1000', 6));
             await mintTxUsdc.wait();
             console.log("MockUSDC minted successfully.");
        } else {
             console.warn(`WARNING: Script's PRIVATE_KEY (0x${wallet.address.slice(2, 10)}...) is not owner of MockUSDC (0x${usdcOwner.slice(2, 10)}...). Skipping MockUSDC mint.`);
             // If not owner, you'd have to ensure tokens are pre-minted or use a different approach.
             // For testing purposes, you might use vm.deal in a Forge test.
        }
       
        // Check if wallet is owner of MockUSDY for minting
        const usdyOwner = await usdyContract.owner();
        if (usdyOwner.toLowerCase() === wallet.address.toLowerCase()) {
            const mintTxUsdy = await usdyContract.mint(user, ethers.parseUnits('1000', 18));
            await mintTxUsdy.wait();
            console.log("MockUSDY minted successfully.");
        } else {
            console.warn(`WARNING: Script's PRIVATE_KEY (0x${wallet.address.slice(2, 10)}...) is not owner of MockUSDY (0x${usdyOwner.slice(2, 10)}...). Skipping MockUSDY mint.`);
        }
        
        console.log(`User ${user} USDC balance:`, ethers.formatUnits(await usdcContract.balanceOf(user), 6));
        console.log(`User ${user} USDY balance:`, ethers.formatUnits(await usdyContract.balanceOf(user), 18));


        // User selects a strategy preference (e.g., low risk)
        console.log('User setting low risk strategy preference...');
        const lowRiskStrategyAddress = DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.low;
        const setUserStrategyTx = await strategyManagerContract.setUserStrategy(lowRiskStrategyAddress);
        await setUserStrategyTx.wait();
        console.log(`User's preferred strategy set to: ${await strategyManagerContract.getUserStrategy(user)}`);

        // User deposits into the Vault
        console.log('User depositing 500 USDC into Vault...');
        const depositAmount = ethers.parseUnits('500', 6);
        const approveTx = await usdcContract.approve(VAULT_ADDRESS, depositAmount); // User approves Vault
        await approveTx.wait();
        console.log("Approval for Vault to spend USDC confirmed.");
        
        const depositTx = await vaultContract.deposit(depositAmount); // FIX: Now `deposit` exists
        await depositTx.wait();
        console.log(`User's Vault deposit: ${ethers.formatUnits(await vaultContract.userDeposits(user), 6)} USDC`);

        // --- ElizaOS Agent's Core Logic (Post-User Actions) ---

        // Agent retrieves user's preferred strategy from StrategyManager
        const userPreferredStrategyFromManager = await strategyManagerContract.getUserStrategy(user);
        console.log(`Agent retrieved user's preferred strategy from manager: ${userPreferredStrategyFromManager}`);

        // Agent determines the optimal DeFi pool for this user's risk profile
        const bestDefiPool = await elizaOS.determineOptimalDefiPool(userPreferredStrategyFromManager);
        console.log('Agent recommends depositing into protocol:', bestDefiPool.protocol, 'with APY:', bestDefiPool.expectedApy);

        // Agent then allocates the user's funds from the Vault to the *corresponding MockStrategy*
        const currentVaultDeposit = await vaultContract.userDeposits(user);
        if (currentVaultDeposit > 0) {
            console.log("Current user vault deposit is:", ethers.formatUnits(currentVaultDeposit, 6), "USDC");
            let targetMockStrategyAddress: string;
            if (bestDefiPool.riskCategory === 'low') {
                targetMockStrategyAddress = DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.low;
            } else if (bestDefiPool.riskCategory === 'high') {
                targetMockStrategyAddress = DEPLOYED_STRATEGY_CONTRACT_ADDRESSES.high;
            } else {
                throw new Error("Invalid risk category determined by agent.");
            }

            await elizaOS.callAllocateFunds(user, currentVaultDeposit, targetMockStrategyAddress);
        } else {
            console.log("No funds in Vault to allocate after deposit simulation.");
        }


        console.log('ElizaOS agent cycle completed successfully.');
    } catch (error) {
        console.error('ElizaOS agent encountered an error:', error);
    }
}

// Ensure these are correctly set in your .env file with actual deployed contract addresses
// after running DeployAllContracts.s.sol
// Example:
// USDC_ADDRESS="0xEB3526161Ac9BfFB139B94a91E7D79B9915E2FE8"
// USDY_ADDRESS="0x9e5D60Ae283e15e81D92499DcD3d7967a3f7A6D9"
// LOW_RISK_STRATEGY_ADDRESS="0x4248d8d1a47d7dF637742f22cB789e942143F8BB"
// HIGH_RISK_STRATEGY_ADDRESS="0x0108b9bc01D9e372f01Db5454eeC5423B72f1833"


main().catch(console.error);

// Export for use in other files (though this script is typically run directly)
export { ElizaOS, MarketData, StrategyInfo };
