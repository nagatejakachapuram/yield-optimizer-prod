// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockAavePool {
    address public immutable USDC;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTime;
    mapping(address => uint256) public claimedYield;
    uint256 public apyBasisPoints; // e.g., 1200 for 12%

    event Supplied(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(address _usdc, uint256 _apyBasisPoints) {
        USDC = _usdc;
        apyBasisPoints = _apyBasisPoints;
    }

    function supply(address asset, uint256 amount, address onBehalfOf, uint16) external {
        require(asset == USDC, "Only USDC allowed");
        require(amount > 0, "Amount must be > 0");

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);

        balances[onBehalfOf] += amount;
        depositTime[onBehalfOf] = block.timestamp;

        emit Supplied(onBehalfOf, amount);
    }

    function getBalance(address user) public view returns (uint256) {
        uint256 principal = balances[user];
        if (principal == 0) return 0;

        uint256 timeHeld = block.timestamp - depositTime[user];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) / (365 days * 10000);
        return principal + totalYield;
    }

    function claimYield() external {
        uint256 principal = balances[msg.sender];
        require(principal > 0, "No deposit");

        uint256 timeHeld = block.timestamp - depositTime[msg.sender];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) / (365 days * 10000);
        uint256 yieldToClaim = totalYield - claimedYield[msg.sender];

        require(yieldToClaim > 0, "No yield available");
        claimedYield[msg.sender] += yieldToClaim;

        IERC20(USDC).transfer(msg.sender, yieldToClaim);
        emit YieldClaimed(msg.sender, yieldToClaim);
    }

    function withdraw() external {
        uint256 principal = balances[msg.sender];
        require(principal > 0, "No balance");

        uint256 timeHeld = block.timestamp - depositTime[msg.sender];
        uint256 totalYield = (principal * apyBasisPoints * timeHeld) / (365 days * 10000);
        uint256 unclaimedYield = totalYield - claimedYield[msg.sender];

        balances[msg.sender] = 0;
        depositTime[msg.sender] = 0;
        claimedYield[msg.sender] = 0;

        uint256 totalToSend = principal + unclaimedYield;
        IERC20(USDC).transfer(msg.sender, totalToSend);

        emit Withdrawn(msg.sender, totalToSend);
    }
}
