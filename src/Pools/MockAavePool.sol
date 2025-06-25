// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

/// @title MockAavePool
/// @notice Simulates basic Aave supply, withdraw, and yield behavior for testing
contract MockAavePool {
    // Custom Errors
    error InvalidAsset();
    error ZeroAmount();
    error NoDeposit();
    error NoBalance();
    error NoYieldAvailable();

    /// @notice Address of the USDC token used in the mock
    address public immutable USDC;

    /// @notice Tracks principal deposited by each user
    mapping(address => uint256) public balances;

    /// @notice Timestamp of the latest deposit for each user
    mapping(address => uint256) public depositTime;

    /// @notice Total yield already claimed by each user
    mapping(address => uint256) public claimedYield;

    /// @notice Simulated APY in basis points (e.g., 500 = 5.00%)
    uint256 public apyBasisPoints;

    /// @notice Emitted when a user supplies assets
    event Supplied(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims yield
    event YieldClaimed(address indexed user, uint256 amount);

    /// @notice Emitted when a user withdraws assets
    event Withdrawn(address indexed user, uint256 amount);

    /// @param _usdc Address of USDC token
    /// @param _apyBasisPoints Annual interest in basis points (e.g., 500 = 5%)
    constructor(address _usdc, uint256 _apyBasisPoints) {
        USDC = _usdc;
        apyBasisPoints = _apyBasisPoints;
    }

    /// @notice Simulates supply of USDC into the pool
    /// @param asset Must be the USDC token
    /// @param amount Amount to supply
    /// @param onBehalfOf The address whose balance will increase
    /// @param referralCode Unused in mock (Aave-specific)
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external {
        console.log("Optional Refferal code:", referralCode);
        if (asset != USDC) revert InvalidAsset();
        if (amount == 0) revert ZeroAmount();

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);

        balances[onBehalfOf] += amount;
        depositTime[onBehalfOf] = block.timestamp;

        emit Supplied(onBehalfOf, amount);
    }

    /// @notice Calculates user's principal + accrued yield
    /// @param user The address to check
    /// @return totalBalance Principal + simulated yield
    function getBalance(address user) public view returns (uint256) {
        uint256 principal = balances[user];
        if (principal == 0) return 0;

        uint256 timeHeld = block.timestamp - depositTime[user];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) /
            (365 days * 10000);

        return principal + totalYield;
    }

    /// @notice Claims available yield and transfers it to the user
    function claimYield() external {
        uint256 principal = balances[msg.sender];
        if (principal == 0) revert NoDeposit();

        uint256 timeHeld = block.timestamp - depositTime[msg.sender];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) /
            (365 days * 10000);
        uint256 yieldToClaim = totalYield - claimedYield[msg.sender];

        if (yieldToClaim == 0) revert NoYieldAvailable();

        claimedYield[msg.sender] += yieldToClaim;
        IERC20(USDC).transfer(msg.sender, yieldToClaim);

        emit YieldClaimed(msg.sender, yieldToClaim);
    }

    /// @notice Withdraws principal from the mock pool
    /// @param asset Must be USDC
    /// @param amount Amount to withdraw
    /// @param to Address to receive the withdrawn funds
    /// @return withdrawnAmount Amount actually withdrawn
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256 withdrawnAmount) {
        if (asset != USDC) revert InvalidAsset();
        uint256 userBal = balances[msg.sender];
        if (userBal < amount) revert NoBalance();

        balances[msg.sender] -= amount;
        IERC20(USDC).transfer(to, amount);

        emit Withdrawn(msg.sender, amount);
        return amount;
    }

    /// @notice Simulates Aave's `getUserAccountData` interface
    /// @dev Only totalCollateralBase is used; others return zero
    /// @param user Address to query
    /// @return totalCollateralBase Simulated total balance (principal + yield)
    /// @return 0
    /// @return 0
    /// @return 0
    /// @return 0
    /// @return 0
    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (getBalance(user), 0, 0, 0, 0, 0);
    }
}
