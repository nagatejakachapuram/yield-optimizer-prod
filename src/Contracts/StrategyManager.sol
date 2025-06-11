// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../Interfaces/IStrategy.sol";

contract StrategyManager {
    mapping(address => address) public userStrategyChoice;
    address public lowRiskStrategy;
    address public highRiskStrategy;
    address public admin;

    event StrategyChosen(address indexed user, address strategy);


    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    constructor(address _lowRisk, address _highRisk, address _admin) {
        require(
            _lowRisk != address(0) &&
                _highRisk != address(0) &&
                _admin != address(0),
            "Invalid address"
        );
        lowRiskStrategy = _lowRisk;
        highRiskStrategy = _highRisk;
        admin = _admin;
    }

    function setUserStrategy(address strategy) external {
        require(
            strategy == lowRiskStrategy || strategy == highRiskStrategy,
            "Invalid strategy"
        );
        userStrategyChoice[msg.sender] = strategy;
        emit StrategyChosen(msg.sender, strategy);

    }

    function executeLowRiskStrategy(
        address user,
        uint256 amount
    ) external onlyAdmin {
        require(
            userStrategyChoice[user] == lowRiskStrategy,
            "User not opted for low risk"
        );
        IStrategy(lowRiskStrategy).execute(user, amount);
    }

    function executeHighRiskStrategy(
        address user,
        uint256 amount
    ) external onlyAdmin {
        require(
            userStrategyChoice[user] == highRiskStrategy,
            "User not opted for high risk"
        );
        IStrategy(highRiskStrategy).execute(user, amount);
    }

    function getUserStrategy(address user) external view returns (address) {
        return userStrategyChoice[user];
    }
}
