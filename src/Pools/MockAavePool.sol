// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAavePool {
    // Custom Errors
    error InvalidAsset();
    error ZeroAmount();
    error NoDeposit();
    error NoBalance();
    error NoYieldAvailable();

    address public immutable USDC;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTime;
    mapping(address => uint256) public claimedYield;
    uint256 public apyBasisPoints;

    event Supplied(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _usdc, uint256 _apyBasisPoints) {
        USDC = _usdc;
        apyBasisPoints = _apyBasisPoints;
    }

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16
    ) external {
        if (asset != USDC) revert InvalidAsset();
        if (amount == 0) revert ZeroAmount();

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);

        balances[onBehalfOf] += amount;
        depositTime[onBehalfOf] = block.timestamp;

        emit Supplied(onBehalfOf, amount);
    }

    function getBalance(address user) public view returns (uint256) {
        uint256 principal = balances[user];
        if (principal == 0) return 0;

        uint256 timeHeld = block.timestamp - depositTime[user];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) /
            (365 days * 10000);
        return principal + totalYield;
    }

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

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        if (asset != USDC) revert InvalidAsset();
        uint256 userBal = balances[msg.sender];
        if (userBal < amount) revert NoBalance();

        balances[msg.sender] -= amount;
        IERC20(USDC).transfer(to, amount);

        emit Withdrawn(msg.sender, amount);
        return amount;
    }

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
