import { ethers } from 'ethers';
import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

// Types
interface MarketData {
    timestamp: number;
    yields: {
        [protocol: string]: {
            apy: number;
            tvl: number;
            risk: number;
        };
    };
    prices: {
        [token: string]: number;
    };
}

interface Strategy {
    id: number;
    protocol: string;
    expectedApy: number;
    risk: number;
    allocation: number;
}

// Contract interface
interface VaultContract extends ethers.BaseContract {
    setApprovedStrategy: (strategyAddress: string, approved: boolean) => Promise<ethers.ContractTransactionResponse>;
    getTotalValueLocked: () => Promise<bigint>;
}

// Constants
const VAULT_ADDRESS = process.env.VAULT_ADDRESS;
const RPC_URL = process.env.SEPOLIA_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

// Placeholder for strategy addresses - REPLACE WITH ACTUAL DEPLOYED STRATEGY ADDRESSES
const STRATEGY_ADDRESSES: { [protocol: string]: string } = {
    'aerodrome-slipstream': '0x3db554fa56b35a43d2c8049fb0f39f9a540fa22c', // Replaced with your deployed MockStrategy address
    'lido': '0x123DEF4567890ABC123DEF4567890ABC123DEF', // Example, replace with actual address
    // Add more mappings as needed for other protocols
};

// Validate environment variables
if (!VAULT_ADDRESS) {
    throw new Error('VAULT_ADDRESS environment variable is not set');
}
if (!RPC_URL) {
    throw new Error('SEPOLIA_RPC_URL environment variable is not set');
}
if (!PRIVATE_KEY) {
    throw new Error('PRIVATE_KEY environment variable is not set');
}

// Initialize provider and signer
const provider = new ethers.JsonRpcProvider(RPC_URL);
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

// Vault ABI - only the functions we need
const VAULT_ABI = [
    "function setApprovedStrategy(address strategy, bool approved) external",
    "function getTotalValueLocked() external view returns (uint256)"
];

// Initialize contract with error handling
let vaultContract: VaultContract;
try {
    const contract = new ethers.Contract(VAULT_ADDRESS, VAULT_ABI, wallet);
    vaultContract = contract as unknown as VaultContract;
} catch (error) {
    console.error('Error initializing Vault contract:', error);
    throw new Error('Failed to initialize Vault contract. Please check your contract address and network configuration.');
}

class ElizaOS {
    private marketData: MarketData | null = null;

    /**
     * Fetches market data from various DeFi APIs
     */
    async fetchMarketData(): Promise<MarketData> {
        console.log('Fetching market data...');
        try {
            // Fetch data from multiple sources
            const [coingeckoData, defillamaData] = await Promise.all([
                this.fetchCoingeckoData(),
                this.fetchDefiLlamaData()
            ]);

            // Combine and process the data
            this.marketData = {
                timestamp: Date.now(),
                yields: {
                    ...(defillamaData.yields || {})
                },
                prices: coingeckoData.prices || {}
            };

            if (!this.marketData) {
                throw new Error('Failed to initialize market data');
            }
            console.log('Market data fetched successfully:', this.marketData);
            return this.marketData;
        } catch (error) {
            console.error('Error fetching market data:', error);
            throw error;
        }
    }

    /**
     * Fetches data from Coingecko API
     */
    private async fetchCoingeckoData(): Promise<Partial<MarketData>> {
        try {
            const response = await axios.get('https://api.coingecko.com/api/v3/simple/price', {
                params: {
                    ids: 'usd-coin,ethereum',
                    vs_currencies: 'usd'
                }
            });

            return {
                prices: response.data as { [token: string]: number }
            };
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
            
            // Process and format the yield data
            const yields = response.data.data.reduce((acc: { [key: string]: any }, pool: any) => {
                acc[pool.project] = {
                    apy: pool.apy,
                    tvl: pool.tvlUsd,
                    risk: this.calculateRiskScore(pool)
                };
                return acc;
            }, {});

            return { yields };
        } catch (error) {
            console.error('Error fetching DeFiLlama data:', error);
            return { yields: {} };
        }
    }

    /**
     * Calculates risk score for a protocol (0-100)
     */
    private calculateRiskScore(pool: any): number {
        // Implement risk scoring logic based on:
        // - TVL
        // - Protocol age
        // - Audit status
        // - Historical performance
        return Math.floor(Math.random() * 100); // Placeholder
    }

    /**
     * Determines the best strategy based on market data
     */
    async determineStrategy(): Promise<Strategy> {
        if (!this.marketData) {
            throw new Error('Market data not fetched');
        }
        console.log('Determining optimal strategy...');
        try {
            // Get TVL from the vault
            const tvl = await vaultContract.getTotalValueLocked();
            console.log('Vault TVL:', ethers.formatUnits(tvl, 6), 'USDC'); // Assuming USDC has 6 decimals

            // Analyze yields and risks
            const strategies = Object.entries(this.marketData.yields)
                .map(([protocol, data]) => ({
                    id: this.generateStrategyId(protocol),
                    protocol,
                    expectedApy: data.apy,
                    risk: data.risk,
                    allocation: this.calculateAllocation(data, tvl)
                }))
                .sort((a, b) => {
                    // Sort by risk-adjusted return
                    const scoreA = a.expectedApy * (100 - a.risk) / 100;
                    const scoreB = b.expectedApy * (100 - b.risk) / 100;
                    return scoreB - scoreA;
                });

            if (strategies.length === 0) {
                throw new Error('No strategies available');
            }
            const bestStrategy = strategies[0];
            console.log('Best strategy determined:', bestStrategy);
            return bestStrategy; // Return the best strategy
        } catch (error) {
            console.error('Error determining strategy:', error);
            throw error;
        }
    }

    /**
     * Generates a unique strategy ID based on protocol name
     */
    private generateStrategyId(protocol: string): number {
        const hash = ethers.keccak256(ethers.toUtf8Bytes(protocol));
        // Convert first 8 bytes of hash to number
        return parseInt(hash.slice(2, 10), 16);
    }

    /**
     * Calculates allocation percentage based on risk and TVL
     */
    private calculateAllocation(data: any, tvl: bigint): number {
        // Implement allocation logic based on:
        // - Risk score
        // - TVL
        // - Protocol limits
        return Math.min(100, Math.max(0, 100 - data.risk));
    }

    // NOTE: The strategyId generated by generateStrategyId is a number, not an address.
    // We need to map this to an actual strategy contract address for `setApprovedStrategy`.
    // For this example, we'll use a placeholder from STRATEGY_ADDRESSES.
    async callSetApprovedStrategy(protocol: string): Promise<void> {
        const strategyAddress = STRATEGY_ADDRESSES[protocol];
        if (!strategyAddress) {
            throw new Error(`No strategy address found for protocol: ${protocol}`);
        }

        console.log(`Calling setApprovedStrategy for ${protocol} at address ${strategyAddress}...`);
        try {
            const tx = await vaultContract.setApprovedStrategy(strategyAddress, true);
            console.log('Transaction sent, hash:', tx.hash);
            await tx.wait();
            console.log('setApprovedStrategy transaction mined successfully.');
        } catch (error) {
            console.error('Error calling setApprovedStrategy:', error);
            throw error;
        }
    }
}

async function main() {
    console.log('ElizaOS agent starting...');
    const elizaOS = new ElizaOS();
    try {
        // Fetch market data
        await elizaOS.fetchMarketData();

        // Determine optimal strategy
        const bestStrategy = await elizaOS.determineStrategy();

        // Call setApprovedStrategy on the Vault contract
        await elizaOS.callSetApprovedStrategy(bestStrategy.protocol);

        console.log('ElizaOS agent cycle completed successfully.');
    } catch (error) {
        console.error('ElizaOS agent encountered an error:', error);
    }
}

main().catch(console.error);

// Export for use in other files
export { ElizaOS, MarketData, Strategy }; 