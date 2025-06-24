// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {YVault} from "./YVault.sol"; // Adjust path to your YVault.sol

/**
 * @title AutomationOwner
 * @notice A secure owner for YVault that allows a trusted Chainlink Automation
 * to update the vault's strategy.
 * @dev This contract should be set as the `vaultOwnerSafe` of the YVault.
 */
contract AutomationOwner {
    address public immutable admin;
    YVault public immutable vault;
    address public upkeepContract;

    event UpkeepContractUpdated(address indexed newUpkeepContract);
    event StrategyUpdatedByUpkeep(address indexed newStrategy);

    error NotAdmin();
    error NotUpkeep();
    error ZeroAddress();

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyUpkeep() {
        if (msg.sender != upkeepContract) revert NotUpkeep();
        _;
    }

    constructor(address _vaultAddress) {
        admin = msg.sender;
        vault = YVault(_vaultAddress);
    }

    /**
     * @notice Admin function to set the trusted Chainlink Upkeep contract address.
     * @param _upkeepContract The address of the Chainlink Automation contract.
     */
    function setUpkeepContract(address _upkeepContract) external onlyAdmin {
        if (_upkeepContract == address(0)) revert ZeroAddress();
        upkeepContract = _upkeepContract;
        emit UpkeepContractUpdated(_upkeepContract);
    }

    /**
     * @notice This function can ONLY be called by the trusted Chainlink Upkeep.
     * It calls the setStrategy function on the YVault.
     * @param _newStrategy The address of the new strategy recommended by Eliza.
     */
    function updateVaultStrategy(address _newStrategy) external onlyUpkeep {
        vault.setStrategy(_newStrategy);
        emit StrategyUpdatedByUpkeep(_newStrategy);
    }

    /**
     * @notice Admin can still call other owner functions on the vault directly.
     * This function acts as a pass-through.
     * @param callData The encoded function call for the vault.
     */
    function executeVaultCall(bytes calldata callData) external onlyAdmin {
        (bool success, ) = address(vault).call(callData);
        require(success, "Vault call failed");
    }
}