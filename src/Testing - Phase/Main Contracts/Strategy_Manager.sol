// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;
import "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StrategyManager is
    Ownable // Inherit Ownable for admin management
{
    mapping(address => address) public userStrategyChoice;
    address public lowRiskStrategy;
    address public highRiskStrategy;

    event StrategyChosen(address indexed user, address strategy);
    event LowRiskStrategyUpdated(
        address indexed oldStrategy,
        address indexed newStrategy
    );
    event HighRiskStrategyUpdated(
        address indexed oldStrategy,
        address indexed newStrategy
    );

    constructor(address _lowRisk, address _highRisk, address _admin) {
        // Initialize Ownable with the admin address
        _transferOwnership(_admin); // Use internal Ownable function to set initial owner
        require(
            _lowRisk != address(0) &&
                _highRisk != address(0) &&
                _admin != address(0),
            "Invalid address"
        );
        lowRiskStrategy = _lowRisk;
        highRiskStrategy = _highRisk;
    }

    function setUserStrategy(address strategy) external {
        // Consider pausable check if you add Pausable to StrategyManager
        require(
            strategy == lowRiskStrategy || strategy == highRiskStrategy,
            "Invalid strategy"
        );
        userStrategyChoice[msg.sender] = strategy;
        emit StrategyChosen(msg.sender, strategy);
    }

    // --- Admin-only functions to update strategies ---
    /**
     * @notice Allows the admin to update the address of the low risk strategy.
     * @dev Only the contract owner (admin) can call this.
     * @param _newLowRiskStrategy The new address for the low risk strategy.
     */
    function setLowRiskStrategy(
        address _newLowRiskStrategy
    ) external onlyOwner {
        require(_newLowRiskStrategy != address(0), "Invalid address");
        require(
            _newLowRiskStrategy != highRiskStrategy,
            "Strategy already set as high risk"
        );
        address oldStrategy = lowRiskStrategy;
        lowRiskStrategy = _newLowRiskStrategy;
        emit LowRiskStrategyUpdated(oldStrategy, _newLowRiskStrategy);
    }

    /**
     * @notice Allows the admin to update the address of the high risk strategy.
     * @dev Only the contract owner (admin) can call this.
     * @param _newHighRiskStrategy The new address for the high risk strategy.
     */
    function setHighRiskStrategy(
        address _newHighRiskStrategy
    ) external onlyOwner {
        require(_newHighRiskStrategy != address(0), "Invalid address");
        require(
            _newHighRiskStrategy != lowRiskStrategy,
            "Strategy already set as low risk"
        );
        address oldStrategy = highRiskStrategy;
        highRiskStrategy = _newHighRiskStrategy;
        emit HighRiskStrategyUpdated(oldStrategy, _newHighRiskStrategy);
    }

    function getUserStrategy(address user) external view returns (address) {
        return userStrategyChoice[user];
    }
}
