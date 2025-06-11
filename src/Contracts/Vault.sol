// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/IStrategy.sol";

contract Vault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public userDeposits;
    uint256 public totalValueLocked;
    IERC20 public usdc;
    address public admin;

    mapping(address => bool) public approvedStrategies;

    /// EVENTS /////
    event DepositSuccessful(address indexed user, uint256 amount);
    event WithdrawalSuccessful(address indexed user, uint256 amount);
    event StrategyApprovalUpdated(address strategy, bool approved);
    event FundsAllocated(
        address indexed user,
        address strategy,
        uint256 amount
    );

    constructor(address _usdcAddress, address _admin) {
        require(_usdcAddress != address(0), "Invalid USDC address");
        require(_admin != address(0), "Invalid admin address");
        admin = _admin;
        usdc = IERC20(_usdcAddress);
    }

    error NotAdmin();
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");

        userDeposits[msg.sender] += amount;
        totalValueLocked += amount;

        usdc.safeTransferFrom(msg.sender, address(this), amount);
        emit DepositSuccessful(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(userDeposits[msg.sender] >= amount, "Insufficient balance");

        userDeposits[msg.sender] -= amount;
        totalValueLocked -= amount;

        usdc.safeTransfer(msg.sender, amount);
        emit WithdrawalSuccessful(msg.sender, amount);
    }

    /// STRATEGY FUNCTIONS ///
    function setApprovedStrategy(
        address strategy,
        bool approved
    ) external onlyAdmin {
        require(strategy != address(0), "Invalid strategy address");

        approvedStrategies[strategy] = approved;
        emit StrategyApprovalUpdated(strategy, approved);
    }

    function allocateFunds(
        address user,
        uint256 amount,
        address strategy
    ) external onlyAdmin nonReentrant {
        require(userDeposits[user] >= amount, "Insufficient balance");
        require(approvedStrategies[strategy], "Strategy not approved");

        // Check strategy is a contract
        uint32 size;
        assembly {
            size := extcodesize(strategy)
        }
        require(size > 0, "Strategy must be a contract");

        userDeposits[user] -= amount;
        totalValueLocked -= amount;

        // Set allowance securely (manual approve pattern)
        // Gas optimization: Reset allowance before approving
        IERC20 token = usdc;
        require(token.approve(strategy, 0), "Reset failed");
        require(token.approve(strategy, amount), "Approve failed");

        IStrategy(strategy).execute(user, amount);
        emit FundsAllocated(user, strategy, amount);
    }

    /// GETTERS ///
    function getUserDeposits() external view returns (uint256) {
        return userDeposits[msg.sender];
    }

    function getTotalValueLocked() external view returns (uint256) {
        return totalValueLocked;
    }

    // Fallback and receive functions to receive ETH
    receive() external payable {
        revert("Vault does not accept ETH");
    }

    fallback() external payable {
        revert("Fallback: Vault does not accept ETH");
    }
}
