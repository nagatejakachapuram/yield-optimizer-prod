// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../Interfaces/IMorpho.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

/// @title MockMorpho
/// @notice Simulates basic Morpho supply, withdraw, and yield accrual for testing purposes
contract MockMorpho is IMorpho {
    // Custom Errors
    error ZeroAmount();
    error NoDeposit();
    error NoBalance();
    error NoYieldAvailable();

    /// @notice Tracks principal balances by user
    mapping(address => uint256) public balances;

    /// @notice Timestamp of latest deposit for each user
    mapping(address => uint256) public depositTime;

    /// @notice Tracks how much yield each user has already claimed
    mapping(address => uint256) public claimedYield;

    /// @notice Address of the USDC token used in the mock
    address public usdc;

    /// @notice Annual yield in basis points (e.g., 500 = 5.00%)
    uint256 public apyBasisPoints;

    /// @param _usdc Address of the mock USDC token
    /// @param _apyBasisPoints Annual percentage yield in basis points (1% = 100)
    constructor(address _usdc, uint256 _apyBasisPoints) {
        usdc = _usdc;
        apyBasisPoints = _apyBasisPoints;
    }

    /// @inheritdoc IMorpho
    /// @notice Simulates supplying assets to the Morpho pool
    /// @param market Ignored in mock
    /// @param amount Amount to supply
    /// @param onBehalf Address credited with the deposit
    function supply(address market, uint256 amount, address onBehalf) external override {
        console.log("MockMorpho market address: %s", market);
        if (amount == 0) revert ZeroAmount();
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);
        balances[onBehalf] += amount;
        depositTime[onBehalf] = block.timestamp;
    }

    /// @inheritdoc IMorpho
    /// @notice Withdraws the specified amount of principal for the user
    /// @param market Ignored in mock
    /// @param amount Amount of principal to withdraw
    /// @param to Recipient of withdrawn funds
    function withdraw(address market, uint256 amount, address to) external override {
        console.log("MockMorpho market address: %s", market);
        if (balances[msg.sender] < amount) revert NoBalance();
        balances[msg.sender] -= amount;
        IERC20(usdc).transfer(to, amount);
    }

    /// @inheritdoc IMorpho
    /// @notice Returns principal + accrued yield for a user
    /// @param market Ignored in mock
    /// @param user Address to query
    /// @return totalBalance User's full balance including simulated yield
    function balanceOf(address market, address user) external view override returns (uint256) {
        console.log("MockMorpho market address: %s", market);
        uint256 principal = balances[user];
        if (principal == 0) return 0;

        uint256 timeHeld = block.timestamp - depositTime[user];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) / (365 days * 10000);
        return principal + totalYield;
    }

    /// @notice Allows users to claim their simulated yield
    function claimYield() external {
        uint256 principal = balances[msg.sender];
        if (principal == 0) revert NoDeposit();

        uint256 timeHeld = block.timestamp - depositTime[msg.sender];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) / (365 days * 10000);
        uint256 yieldToClaim = totalYield - claimedYield[msg.sender];

        if (yieldToClaim == 0) revert NoYieldAvailable();

        claimedYield[msg.sender] += yieldToClaim;
        IERC20(usdc).transfer(msg.sender, yieldToClaim);
    }
}
