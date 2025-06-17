// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/Contracts/Vault.sol";
import "../src/Contracts/StrategyManager.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockUSDY.sol";
import "../src/mocks/MockPriceFeed.sol";
import "../src/mocks/MockSwap.sol";
import "../src/mocks/MockStrategy.sol";

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
        address chainlink_Admin = deployer;
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
            deployer,
            chainlink_Admin
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
