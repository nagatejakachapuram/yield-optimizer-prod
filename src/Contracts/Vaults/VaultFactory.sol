// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./YVault.sol";

/// @title VaultFactory - Deploys YVaults for different risk levels
contract VaultFactory is Ownable {
    enum RiskLevel {
        LOW,
        HIGH
    }

    address public immutable USDC;
    address public multisigSafe;

    mapping(RiskLevel => address) public vaultByRisk;

    event VaultDeployed(address indexed vault, RiskLevel risk, string name);

    error ZeroAddress();
    error VaultAlreadyDeployed();
    error MultisigZeroAddress();

    constructor(address _USDC, address _multisigSafe) {
        if (_USDC == address(0) || _multisigSafe == address(0)) revert ZeroAddress();
        USDC = _USDC;
        multisigSafe = _multisigSafe;
    }

    function deployVaults() external onlyOwner {
        if (vaultByRisk[RiskLevel.LOW] != address(0) || vaultByRisk[RiskLevel.HIGH] != address(0)) {
            revert VaultAlreadyDeployed();
        }

        vaultByRisk[RiskLevel.LOW] = _deployVault("AI Vault - Low Risk", "aiLOW", RiskLevel.LOW);
        vaultByRisk[RiskLevel.HIGH] = _deployVault("AI Vault - High Risk", "aiHIGH", RiskLevel.HIGH);
    }

    function _deployVault(
        string memory name,
        string memory symbol,
        RiskLevel risk
    ) internal returns (address vaultAddr) {
        YVault vault = new YVault(USDC, name, symbol, multisigSafe);
        vaultAddr = address(vault);
        emit VaultDeployed(vaultAddr, risk, name);
    }

    function getVaultByRisk(RiskLevel risk) external view returns (address) {
        return vaultByRisk[risk];
    }

    function updateMultisigSafe(address newSafe) external onlyOwner {
        if (newSafe == address(0)) revert MultisigZeroAddress();
        multisigSafe = newSafe;
    }
}
