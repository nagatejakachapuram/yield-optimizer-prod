// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YVault.sol";

/// @title VaultFactory - Deploys YVaults for different risk levels
/// @author 
/// @notice This factory allows the owner to deploy low-risk and high-risk yield vaults
/// @dev Each vault is deployed only once and stores its address by risk level
contract VaultFactory is Ownable {
    /// @notice Enum for categorizing vaults by risk level
    enum RiskLevel {
        LOW,
        HIGH
    }

    /// @notice The USDC token address used across all vaults
    address public immutable USDC;

    /// @notice The multisig safe which is set as vault owner for all deployed vaults
    address public multisigSafe;

    /// @notice Mapping from risk level to the corresponding vault address
    mapping(RiskLevel => address) public vaultByRisk;

    /// @notice Emitted when a vault is deployed
    /// @param vault The address of the deployed vault
    /// @param risk The risk level (LOW or HIGH) of the vault
    /// @param name The name of the vault
    event VaultDeployed(address indexed vault, RiskLevel risk, string name);

    /// @notice Reverts if address provided is zero
    error ZeroAddress();

    /// @notice Reverts if vaults are already deployed
    error VaultAlreadyDeployed();

    /// @notice Reverts if new multisig safe address is zero
    error MultisigZeroAddress();

    /// @param _USDC The address of the USDC token
    /// @param _multisigSafe The multisig safe address to be set as owner of new vaults
    constructor(address _USDC, address _multisigSafe) {
        if (_USDC == address(0) || _multisigSafe == address(0)) revert ZeroAddress();
        USDC = _USDC;
        multisigSafe = _multisigSafe;
    }

    /// @notice Deploys both LOW and HIGH risk vaults
    /// @dev Only callable once; stores vaults by risk level
    function deployVaults() external onlyOwner {
        if (vaultByRisk[RiskLevel.LOW] != address(0) || vaultByRisk[RiskLevel.HIGH] != address(0)) {
            revert VaultAlreadyDeployed();
        }

        vaultByRisk[RiskLevel.LOW] = _deployVault("AI Vault - Low Risk", "aiLOW", RiskLevel.LOW);
        vaultByRisk[RiskLevel.HIGH] = _deployVault("AI Vault - High Risk", "aiHIGH", RiskLevel.HIGH);
    }

    /// @notice Internal function to deploy a YVault
    /// @param name The name of the vault
    /// @param symbol The symbol of the vault
    /// @param risk The risk level of the vault
    /// @return vaultAddr The address of the newly deployed vault
    function _deployVault(
        string memory name,
        string memory symbol,
        RiskLevel risk
    ) internal returns (address vaultAddr) {
        YVault vault = new YVault(USDC, name, symbol, multisigSafe);
        vaultAddr = address(vault);
        emit VaultDeployed(vaultAddr, risk, name);
    }

    /// @notice Returns the vault address for a given risk level
    /// @param risk The risk level to query
    /// @return The address of the corresponding vault
    function getVaultByRisk(RiskLevel risk) external view returns (address) {
        return vaultByRisk[risk];
    }

    /// @notice Updates the multisigSafe address used for vault ownership
    /// @dev Only callable by the contract owner
    /// @param newSafe The new multisig safe address
    function updateMultisigSafe(address newSafe) external onlyOwner {
        if (newSafe == address(0)) revert MultisigZeroAddress();
        multisigSafe = newSafe;
    }
}
