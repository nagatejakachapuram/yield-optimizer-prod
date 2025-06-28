// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
// // import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
// // import {MockPoRFeedInterface} from "../../Interfaces/MockPoRFeedInterface.sol"; // For future PoR integration

// /// @title Archived YVault Functions
// /// @notice These are non-final functions from YVault that were commented out during optimization or refactor.
// /// @dev They are preserved for reference but not used in production.

// contract YVault_Archived {
// // Original context: intended for internal use in strategy migration

// // function setDYIOracle(address _oracle) external onlyVaultOwner {
// //     dyiOracle = AggregatorV3Interface(_oracle);
// // }

// /*
//     /// @notice Set the Chainlink Defi Yield Index
//     /// @param _porFeed Address of the PoR feed contract
//     // function _getDYI() internal view returns (int256) {
//     //     (, int256 yield,,,) = dyiOracle.latestRoundData();
//     //     return yield;
//     // }
//     */

// /*
//     /// @notice Set the Chainlink Proof of Reserve feed (PoR)
//     /// @param _porFeed Address of the PoR feed contract
//     function setPoRFeed(address _porFeed) external onlyVaultOwner {
//         if (_porFeed == address(0)) revert ZeroAddress();
//         porFeed = MockPoRFeedInterface(_porFeed);
//     }
//     */

// /*
//     /// @notice Check the Proof of Reserve status from Chainlink
//     /// @return isHealthy True if the reserve backing is healthy
//     function checkPoRHealthy() public view returns (bool isHealthy) {
//         require(address(porFeed) != address(0), "PoR feed not set");
//         return porFeed.isHealthy();
//     }
//     */

// // /// @notice
// // AggregatorV3Interface public dyiOracle;

// // /// @notice Optional Chainlink Proof of Reserve feed
// // MockPoRFeedInterface public porFeed;
// }
