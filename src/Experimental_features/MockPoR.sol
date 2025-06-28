// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title MockPoRFeedInterface
/// @notice Minimal interface for Chainlink PoR feed
interface MockPoRFeedInterface {
    function isHealthy() external view returns (bool);
}
