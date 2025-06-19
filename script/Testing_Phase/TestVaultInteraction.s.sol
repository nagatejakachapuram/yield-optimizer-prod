// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import {Vault} from "../../src/Testing_Phase/Main Contracts/Vault_Mock.sol";
import {StrategyManager} from "../../src/Testing_Phase/Main Contracts/Strategy_Manager.sol";
import "../../src/Testing_Phase/Mocks/MockUSDC.sol";
import "../../src/Testing_Phase/Mocks/MockUSDY.sol";
import "../../src/Testing_Phase/Mocks/MockPriceFeed.sol";
import "../../src/Testing_Phase/Mocks/MockSwap.sol";
import "../../src/Testing_Phase/Mocks/MockStrategy.sol";
import {DeployAllContracts} from "./DeployAllContracts.s.sol";

contract TestVaultInteraction is Script {
    Vault public vault;
    StrategyManager public strategyManager;
    MockUSDC public usdc;
    MockUSDY public usdy;
    MockSwap public mockSwap;
    MockStrategy public lowRiskStrategy;
    MockStrategy public highRiskStrategy;
    MockPriceFeed public mockPriceFeed;

    function setUp() public {
        console.log("\n--- TestVaultInteraction: setUp() RUNNING ---");
        address currentScriptSender = msg.sender;
        console.log("Current script sender:", currentScriptSender);

        (vault, strategyManager, usdc, usdy, mockSwap, mockPriceFeed, lowRiskStrategy, highRiskStrategy) =
            new DeployAllContracts().run();

        vm.label(address(vault), "TestVault");
        vm.label(address(strategyManager), "TestStrategyManager");
        vm.label(address(usdc), "TestUSDC");
        vm.label(address(usdy), "TestUSDY");
        vm.label(address(mockSwap), "TestMockSwap");
        vm.label(address(mockPriceFeed), "TestMockPriceFeed");
        vm.label(address(lowRiskStrategy), "TestLowRiskStrategy");
        vm.label(address(highRiskStrategy), "TestHighRiskStrategy");

        console.log("Deployed Vault at:", address(vault));
        console.log("Deployed StrategyManager at:", address(strategyManager));
        console.log("--- TestVaultInteraction: setUp() END ---");
    }

    function run() public {
        console.log("\n--- TestVaultInteraction: run() RUNNING ---");
        console.log("Script caller (msg.sender) for run():", msg.sender);
        console.log("Vault Admin (should be script caller):", vault.admin());

        vm.startBroadcast();

        // 1. Mint USDC and USDY to msg.sender (your test account)
        console.log("Minting tokens to", msg.sender);
        usdc.mint(msg.sender, 1000 * 10 ** 6); // Mint 1,000 USDC
        usdy.mint(msg.sender, 1000 * 10 ** 18); // Mint 1,000 USDY
        console.log("Sender USDC balance after mint:", usdc.balanceOf(msg.sender));
        console.log("Sender USDY balance after mint:", usdy.balanceOf(msg.sender));

        // 2. Approve Vault for USDC deposit
        console.log("Approving Vault for USDC deposit...");
        usdc.approve(address(vault), 1000 * 10 ** 6);
        console.log("Vault allowance for sender (USDC):", usdc.allowance(msg.sender, address(vault)));

        // 3. Deposit USDC into Vault
        console.log("Depositing 1,000 USDC into Vault...");
        vault.deposit(1000 * 10 ** 6);
        console.log("Vault's USDC balance after deposit:", usdc.balanceOf(address(vault)));
        console.log("Sender's Vault deposit:", vault.userDeposits(msg.sender));

        // 4. Withdraw USDC from Vault
        console.log("Withdrawing 500 USDC from Vault...");
        vault.withdraw(500 * 10 ** 6);
        console.log("Vault's USDC balance after withdraw:", usdc.balanceOf(address(vault)));
        console.log("Sender's Vault deposit after withdraw:", vault.userDeposits(msg.sender));

        // 5. Example: Set user strategy preference (via StrategyManager)
        console.log("Setting user strategy preference to low risk...");
        strategyManager.setUserStrategy(address(lowRiskStrategy));
        console.log("Sender's chosen strategy:", strategyManager.getUserStrategy(msg.sender));

        // 6. Approve Vault for USDY swap (Vault will then approve MockSwap)
        console.log("Approving Vault for USDY swap...");
        usdy.approve(address(vault), 100 * 10 ** 18);
        console.log("Vault allowance for sender (USDY):", usdy.allowance(msg.sender, address(vault)));

        // 7. Perform a USDY to USDC swap through the Vault
        console.log("Performing 100 USDY to USDC swap through Vault...");
        vault.swapUSDYtoUSDC(100 * 10 ** 18);
        console.log("Sender's USDC balance after swap:", usdc.balanceOf(msg.sender));
        console.log("Sender's USDY balance after swap:", usdy.balanceOf(msg.sender));
        console.log("Vault's USDY balance after swap:", usdy.balanceOf(address(vault)));

        // 8. (Optional) Example: AI agent allocates funds based on user preference
        // Ensure msg.sender (your private key's address) is indeed the Vault admin
        console.log("Allocating funds based on user preference...");
        address userPreferredStrategy = strategyManager.getUserStrategy(msg.sender);
        uint256 senderVaultDeposit = vault.userDeposits(msg.sender);
        console.log("User preferred strategy:", userPreferredStrategy);
        console.log("User current Vault deposit (before allocation):", senderVaultDeposit);

        if (senderVaultDeposit > 0) {
            vault.allocateFunds(msg.sender, senderVaultDeposit, userPreferredStrategy);
            console.log("Funds allocated. Sender's Vault deposit after allocation:", vault.userDeposits(msg.sender));
        } else {
            console.log("No funds to allocate after swap and withdraws.");
        }
        vm.stopBroadcast();
    }
}
