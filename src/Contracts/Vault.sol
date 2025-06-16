// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "../Interfaces/IStrategy.sol";
import "../Interfaces/IMockSwap.sol";

contract Vault is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public userDeposits;
    uint256 public totalValueLocked;
    IERC20 public immutable usdc;
    IERC20 public immutable usdy;
    address public admin;
    address public pendingAdmin;
    address public immutable mockSwap;

    mapping(address => bool) public approvedStrategies;

    /// EVENTS ///
    event DepositSuccessful(address indexed user, uint256 amount);
    event WithdrawalSuccessful(address indexed user, uint256 amount);
    event StrategyApprovalUpdated(address indexed strategy, bool approved);
    event FundsAllocated(
        address indexed user,
        address indexed strategy,
        uint256 amount
    );
    event AdminTransferProposed(address indexed newAdmin);
    event AdminTransferAccepted(address indexed newAdmin);
    event TokensRecovered(
        address indexed tokenAddress,
        address indexed recipient,
        uint256 amount
    );

    constructor(
        address _usdcAddress,
        address _usdyAddress,
        address _mockSwap,
        address _admin
    ) {
        // Input validation
        require(_usdcAddress != address(0), "Invalid USDC address");
        require(_usdyAddress != address(0), "Invalid USDY address");
        require(_mockSwap != address(0), "Invalid MockSwap address");
        require(_admin != address(0), "Invalid admin address");

        usdc = IERC20(_usdcAddress);
        usdy = IERC20(_usdyAddress);
        mockSwap = _mockSwap;
        admin = _admin;
    }

    // Custom error for access control
    error NotAdmin();
    // Modifier to restrict functions to only the admin
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    // --- Admin Transfer Functions ---
    /**
     * @notice Proposes a new address to become the admin of the Vault.
     * @dev Only the current admin can call this. The transfer is not immediate;
     * the new admin must accept it by calling `acceptAdminOwnership`.
     * @param newAdmin The address of the proposed new admin.
     */
    function transferAdminOwnership(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "New admin cannot be zero address");
        pendingAdmin = newAdmin;
        emit AdminTransferProposed(newAdmin);
    }

    /**
     * @notice Accepts the proposed admin ownership transfer.
     * @dev Only the `pendingAdmin` can call this. Finalizes the admin transfer.
     */
    function acceptAdminOwnership() external {
        require(msg.sender == pendingAdmin, "You are not the pending admin");
        admin = pendingAdmin; // Set the new admin
        pendingAdmin = address(0); // Clear the pending admin
        emit AdminTransferAccepted(admin);
    }

    // --- Pausable Functions (Admin-controlled) ---
    /**
     * @notice Pauses the contract, preventing most operations.
     * @dev Only the admin can call this.
     */
    function pause() external onlyAdmin whenNotPaused {
        _pause(); // Internal OpenZeppelin Pausable function
    }

    /**
     * @notice Unpauses the contract, allowing operations to resume.
     * @dev Only the admin can call this.
     */
    function unpause() external onlyAdmin whenPaused {
        _unpause(); // Internal OpenZeppelin Pausable function
    }

    // --- Core Vault Deposit & Withdrawal Functions ---

    /**
     * @notice Allows a user (msg.sender) to deposit USDC into the Vault for themselves.
     * @dev Funds are transferred from msg.sender to the Vault.
     * @param amount The amount of USDC to deposit.
     */
    function deposit(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");

        // Update user's deposit balance and total value locked
        userDeposits[msg.sender] += amount;
        totalValueLocked += amount;
        // msg.sender must have approved the Vault to spend their USDC
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit DepositSuccessful(msg.sender, amount);
    }

    /**
     * @notice Allows a user (msg.sender) to withdraw their deposited USDC from the Vault.
     * @dev Funds are transferred from the Vault back to msg.sender.
     * @param amount The amount of USDC to withdraw.
     */
    function withdraw(uint256 amount) external nonReentrant whenNotPaused {
        require(amount > 0, "Amount must be greater than zero");
        require(userDeposits[msg.sender] >= amount, "Insufficient balance");

        // Decrease user's deposit balance and total value locked
        userDeposits[msg.sender] -= amount;
        totalValueLocked -= amount;

        // Transfer USDC from Vault to user
        usdc.safeTransfer(msg.sender, amount);
        emit WithdrawalSuccessful(msg.sender, amount);
    }

    /// STRATEGY MANAGEMENT FUNCTIONS ///

    /**
     * @notice Allows the admin to approve or unapprove an investment strategy.
     * @dev Only approved strategies can receive funds via `allocateFunds`.
     * @param strategy The address of the strategy contract.
     * @param approved Boolean indicating whether the strategy is approved (`true`) or not (`false`).
     */
    function setApprovedStrategy(
        address strategy,
        bool approved
    ) external onlyAdmin whenNotPaused {
        require(strategy != address(0), "Invalid strategy address");

        approvedStrategies[strategy] = approved;
        emit StrategyApprovalUpdated(strategy, approved);
    }

    /**
     * @notice Allows the admin to allocate a user's funds to an approved strategy.
     * @dev Funds are deducted from the user's `userDeposits` and sent to the strategy.
     * The Vault approves the strategy to pull the funds.
     * @param user The address of the user whose funds are being allocated.
     * @param amount The amount of USDC to allocate.
     * @param strategy The address of the approved strategy contract.
     */
    function allocateFunds(
        address user,
        uint256 amount,
        address strategy
    ) external onlyAdmin nonReentrant whenNotPaused {
        require(amount > 0, "Allocation amount must be greater than zero");
        require(userDeposits[user] >= amount, "Insufficient balance");
        require(approvedStrategies[strategy], "Strategy not approved");

        uint32 size;
        assembly {
            size := extcodesize(strategy)
        }
        require(size > 0, "Strategy must be a contract");

        userDeposits[user] -= amount;

        // Transfer funds directly to the strategy
        usdc.safeTransfer(strategy, amount);

        IStrategy(strategy).execute(user, amount);
        emit FundsAllocated(user, strategy, amount);
    }

    /**
     * @notice Allows a user (msg.sender) to deposit USDY, which is immediately converted to USDC
     * via MockSwap, and the resulting USDC is recorded as their deposit.
     * @dev Funds are transferred from msg.sender's USDY balance to the Vault,
     * then swapped, and the USDC received is added to userDeposits.
     * @param amount The amount of USDY to deposit and convert.
     */
    function swapUSDYtoUSDC(uint256 amount) external nonReentrant whenNotPaused {
    require(amount > 0, "Amount must be greater than 0");
    require(usdy.balanceOf(msg.sender) >= amount, "Insufficient USDY balance");

    usdy.safeTransferFrom(msg.sender, address(this), amount);

    // Pre-calculate expected output for internal accounting
    uint256 expectedUsdc = amount / 1e12; // e.g. 18 -> 6 decimals

    // Update accounting BEFORE external call
    userDeposits[msg.sender] += expectedUsdc;
    totalValueLocked += expectedUsdc;

    // Approve and call external swap
    usdy.safeApprove(mockSwap, amount);
    uint256 actualUsdc = IMockSwap(mockSwap).swapUSDYtoUSDC(amount);
    require(actualUsdc == expectedUsdc, "Unexpected swap output");

    emit DepositSuccessful(msg.sender, expectedUsdc);
}


    // --- Emergency Token Recovery Function ---
    /**
     * @notice Allows the admin to recover accidentally sent ERC20 tokens.
     * @dev Prevents recovery of main Vault assets (USDC, USDY).
     * @param tokenAddress The address of the ERC20 token to recover.
     * @param amount The amount of the token to recover.
     */
    function recoverERC20(
        IERC20 tokenAddress,
        uint256 amount
    ) external onlyAdmin {
        require(tokenAddress != usdc, "Cannot recover USDC: main asset");
        require(tokenAddress != usdy, "Cannot recover USDY: main asset");
        require(amount > 0, "Recovery amount must be greater than zero");
        // Ensure the contract actually has enough of the token to transfer
        require(
            tokenAddress.balanceOf(address(this)) >= amount,
            "Insufficient token balance in Vault for recovery"
        );

        // Transfer the unwanted tokens to the admin
        tokenAddress.safeTransfer(admin, amount);
        emit TokensRecovered(address(tokenAddress), admin, amount);
    }

    /// GETTERS ///
    /**
     * @notice Returns the amount of USDC deposited by the caller.
     * @return The user's deposited amount.
     */
    function getUserDeposits() external view returns (uint256) {
        return userDeposits[msg.sender];
    }

    /**
     * @notice Returns the total amount of USDC managed by the Vault (sum of all user deposits).
     * @return The total value locked in the Vault.
     */
    function getTotalValueLocked() external view returns (uint256) {
        return totalValueLocked;
    }

    // Fallback and receive functions to reject direct ETH transfers
    receive() external payable {
        revert("Vault does not accept ETH");
    }

    fallback() external payable {
        revert("Fallback: Vault does not accept ETH");
    }
}
