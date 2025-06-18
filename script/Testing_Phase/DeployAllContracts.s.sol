// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../../src/Testing_Phase/Main Contracts/Vault_Mock.sol";
import "../../src/Testing_Phase/Main Contracts/Strategy_Manager.sol";
import "../../src/Testing_Phase/Mocks/MockUSDC.sol";
import "../../src/Testing_Phase/Mocks/MockUSDY.sol";
import "../../src/Testing_Phase/Mocks/MockPriceFeed.sol";
import "../../src/Testing_Phase/Mocks/MockSwap.sol";
import "../../src/Testing_Phase/Mocks/MockStrategy.sol";

contract DeployAllContracts is Script {
    function run()
        public
        returns (
            Vault vault,
            StrategyManager strategyManager,
            MockUSDC usdc,
            MockUSDY usdy,
            MockSwap mockSwap,
            MockPriceFeed mockPriceFeed,
            MockStrategy lowRiskStrategy,
            MockStrategy highRiskStrategy
        )
    {
        address deployer = msg.sender;
        vm.startBroadcast(deployer);
        // 1. Deploy Mock Tokens
        usdc = new MockUSDC();
        usdy = new MockUSDY();

        usdc.mint(deployer, 1_000_000 * 10 ** 6);
        usdy.mint(deployer, 1_000_000 * 10 ** 18);

        // 2. Deploy Mock Price Feed (USDY/USDC, 1:1)
        mockPriceFeed = new MockPriceFeed(1e8, 8);

        // 3. Deploy Mock Swap
        mockSwap = new MockSwap(
            address(usdc),
            address(usdy),
            address(mockPriceFeed)
        );

        usdc.transfer(address(mockSwap), 500_000 * 10 ** 6); // 500k USDC liquidity

        // 4. Deploy Strategies
        lowRiskStrategy = new MockStrategy(address(usdc));
        highRiskStrategy = new MockStrategy(address(usdc));

        // 5. Deploy Vault
        vault = new Vault(
            address(usdc),
            address(usdy),
            address(mockSwap),
            deployer
        );

        // 6. Deploy StrategyManager
        strategyManager = new StrategyManager(
            address(lowRiskStrategy),
            address(highRiskStrategy),
            deployer
        );

        // 7. Admin: Approve strategies in Vault
        vault.setApprovedStrategy(address(lowRiskStrategy), true);
        vault.setApprovedStrategy(address(highRiskStrategy), true);

        vm.stopBroadcast();
    }
}
