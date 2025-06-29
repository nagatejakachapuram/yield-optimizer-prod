// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {MockAavePool} from "../src/Pools/MockAavePool.sol";
import {MockMorpho} from "../src/Pools/MockMorphoPool.sol";
import {LowRiskAaveStrategy} from "../src/Contracts/Strategies/LowRiskAaveStrategy.sol";
import {HighRiskMorphoStrategy} from "../src/Contracts/Strategies/HighRiskMorphoStrategy.sol";
import {YVault} from "../src/Contracts/Vaults/YVault.sol";

contract DeployStrategies is Script {
    address public constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;

    // Replace with the actual addresses obtained after running DeployVaults
    address public constant MOCK_AAVE_POOL = 0x6deb956da4300Fe538efB475D05e818e7D4F3699; 
    address public constant MOCK_MORPHO_POOL = 0x779D4755eF3574467Da5B4909629106794A9dd28; 
    address public constant LOW_VAULT = 0xb32a6FF65dcC2099513970EA5c1eaA87fe564253; 
    address public constant HIGH_VAULT = 0x721bF349E453cbFB68536d3a5757A70B74D84279; 

    function run() external {
        vm.startBroadcast();

        LowRiskAaveStrategy lowRisk = new LowRiskAaveStrategy(
            USDC_SEPOLIA,
            MOCK_AAVE_POOL,
            LOW_VAULT
        );
        console.log("LowRiskStrategy:", address(lowRisk));

        HighRiskMorphoStrategy highRisk = new HighRiskMorphoStrategy(
            USDC_SEPOLIA,
            MOCK_MORPHO_POOL,
            USDC_SEPOLIA,
            HIGH_VAULT
        );
        console.log("HighRiskStrategy:", address(highRisk));

        // Approvals
        lowRisk.approveSpending();
        highRisk.approveSpending();
        console.log("Spending approved");

        // Assign to vaults
        YVault(LOW_VAULT).setStrategy(address(lowRisk));
        YVault(HIGH_VAULT).setStrategy(address(highRisk));
        console.log("Strategies set");

        vm.stopBroadcast();
    }
}
