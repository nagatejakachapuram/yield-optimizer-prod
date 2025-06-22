// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// import "forge-std/Script.sol";
// import "forge-std/console.sol";

// import {MockAavePool} from "../src/Pools/MockAavePool.sol";
// import {MockMorpho} from "../src/Pools/MockMorphoPool.sol";

// import {LowRiskAaveStrategy} from "../src/Contracts/Strategies/LowRiskAaveStrategy.sol";
// import {HighRiskMorphoStrategy} from "../src/Contracts/Strategies/HighRiskMorphoStrategy.sol";

// import {VaultFactory} from "../src/Contracts/Vaults/VaultFactory.sol";
// import {YVault} from "../src/Contracts/Vaults/YVault.sol";

// contract DeployAll is Script {
//     address public constant USDC_SEPOLIA =
//         0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
//     address public constant CHAINLINK_KEEPER =
//         0x000000000000000000000000000000000000dEaD;

//     uint256 public constant AAVE_APY_BPS = 500;
//     uint256 public constant MORPHO_APY_BPS = 850;

//     bytes32 private constant LOW_KEY = keccak256("lastLowRiskPoolId");
//     bytes32 private constant HIGH_KEY = keccak256("lastHighRiskPoolId");

//     function run() external {
//         vm.startBroadcast();

//         // === Load agent JSON ===
//         string memory lowJson = vm.readFile(".local-kv-strategy:low.json");
//         string memory highJson = vm.readFile(".local-kv-strategy:high.json");

//         string memory lowPoolId = vm.parseJsonString(
//             lowJson,
//             ".selectedPool.address"
//         );
//         string memory highPoolId = vm.parseJsonString(
//             highJson,
//             ".selectedPool.address"
//         );

//         // === Check if new deployment needed ===
//         string memory lastLow = vm.load(LOW_KEY);
//         string memory lastHigh = vm.load(HIGH_KEY);

//         bool deployLow = keccak256(bytes(lowPoolId)) !=
//             keccak256(bytes(lastLow));
//         bool deployHigh = keccak256(bytes(highPoolId)) !=
//             keccak256(bytes(lastHigh));

//         address currentUSDC = USDC_SEPOLIA;

//         // === Deploy VaultFactory ===
//         VaultFactory factory = new VaultFactory(currentUSDC, msg.sender);
//         factory.deployVaults();
//         address lowRiskVault = factory.vaultByRisk(VaultFactory.RiskLevel.LOW);
//         address highRiskVault = factory.vaultByRisk(
//             VaultFactory.RiskLevel.HIGH
//         );

//         YVault(lowRiskVault).setChainlinkKeeper(CHAINLINK_KEEPER);
//         YVault(highRiskVault).setChainlinkKeeper(CHAINLINK_KEEPER);

//         if (deployLow) {
//             console.log("Deploying new LowRisk Aave mock/strategy...");
//             MockAavePool mockAave = new MockAavePool(currentUSDC, AAVE_APY_BPS);
//             LowRiskAaveStrategy lowStrat = new LowRiskAaveStrategy(
//                 currentUSDC,
//                 address(mockAave),
//                 lowRiskVault
//             );
//             lowStrat.approveSpending();
//             YVault(lowRiskVault).setStrategy(address(lowStrat));

//             // Store updated pool address
//             vm.store(LOW_KEY, lowPoolId);
//         } else {
//             console.log("Skipping LowRisk strategy deployment....same pool ID.");
//         }

//         if (deployHigh) {
//             console.log("Deploying new HighRisk Morpho mock/strategy...");
//             MockMorpho mockMorpho = new MockMorpho(currentUSDC);
//             HighRiskMorphoStrategy highStrat = new HighRiskMorphoStrategy(
//                 currentUSDC,
//                 address(mockMorpho),
//                 currentUSDC,
//                 highRiskVault
//             );
//             highStrat.approveSpending();
//             YVault(highRiskVault).setStrategy(address(highStrat));

//             // Store updated pool address
//             vm.store(HIGH_KEY, highPoolId);
//         } else {
//             console.log(
//                 "Skipping HighRisk strategy deployment ..... same pool ID."
//             );
//         }

//         console.log("DeployAll finished");

//         vm.stopBroadcast();
//     }
// }
