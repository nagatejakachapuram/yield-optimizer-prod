// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

import "../Interfaces/IStrategy.sol";

contract Vault is ReentrancyGuard, Pausable, AutomationCompatibleInterface {
    using SafeERC20 for IERC20;

    // --- State Variables ---
    mapping(address => uint256) public userDeposits;
    uint256 public totalValueLocked;
    IERC20 public immutable usdc;
    address public admin;
    address public chainlink_Admin;
    address public pendingAdmin;
    address[] public userAddresses;

    mapping(address => bool) public approvedStrategies;

    // --- Automation State ---
    struct AllocationRequest {
        address user;
        uint256 amount;
        address strategy;
    }
    AllocationRequest[] public allocationQueue;

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
    event AllocationRequestQueued(
        address indexed user,
        uint256 amount,
        address indexed strategy
    );


    constructor(
        address _usdcAddress,
        address _admin
    ) {
        // Input validation
        require(_usdcAddress != address(0), "Invalid USDC address");
        require(_admin != address(0), "Invalid admin address");

        usdc = IERC20(_usdcAddress);
        admin = _admin;
    }

    // --- Modifiers ---
    error NotAdmin();
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    error NotChainlinkAdmin();
    modifier onlyChainlinkAdmin() {
        if (msg.sender != chainlink_Admin) revert NotChainlinkAdmin();
        _;
    }

    // --- Set Chainlink Admin ---
    /**
     *
     * @param _admin The address of the new Chainlink admin.
     * @dev Only the current admin can call this.
     * @notice This function allows the current admin to propose a new Chainlink admin.
     */
    function setChainlinkAdmin(address _admin) external onlyAdmin {
        chainlink_Admin = _admin;
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
    function pause() external onlyAdmin {
        _pause(); // Internal OpenZeppelin Pausable function
    }

    /**
     * @notice Unpauses the contract, allowing operations to resume.
     * @dev Only the admin can call this.
     */
    function unpause() external onlyAdmin {
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
    ) public onlyChainlinkAdmin nonReentrant whenNotPaused {
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
    
    /// ADMIN FUNCTIONS ///
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

    /// AUTOMATION ///

    /**
     * @notice Allows the admin to queue an allocation request.
     * @dev The request will be processed by Chainlink Automation.
     * @param user The address of the user whose funds are being allocated.
     * @param amount The amount of USDC to allocate.
     * @param strategy The address of the approved strategy contract.
     */
    function queueAllocation(
        address user,
        uint256 amount,
        address strategy
    ) external onlyAdmin {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Amount must be greater than zero");
        require(strategy != address(0), "Invalid strategy address");
        require(approvedStrategies[strategy], "Strategy not approved");
        require(userDeposits[user] >= amount, "Insufficient balance for user");

        allocationQueue.push(AllocationRequest(user, amount, strategy));
        emit AllocationRequestQueued(user, amount, strategy);
    }

    /**
     * @notice This function is called by Chainlink Automation nodes to check if an upkeep is needed.
     * @dev It returns true if the allocation queue has one or more requests.
     * @return upkeepNeeded A boolean indicating whether `performUpkeep` should be called.
     * @return performData Data to be passed to `performUpkeep` (not used in this implementation).
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = (allocationQueue.length > 0);
        // We don't use the performData in this example. The performData is defined when the Upkeep was registered.
        return (upkeepNeeded, bytes(""));
    }

  
    function performUpkeep(bytes calldata /* performData */) external override {
        // We don't use the performData in this example. The performData is generated by the Automation Node's call to your checkUpkeep function
        uint256 queueLength = allocationQueue.length;
        if (queueLength > 0) {
            // Copy the queue from storage to memory to avoid potential re-entrancy
            // and to work with a fixed-size loop.
            AllocationRequest[] memory queuedRequests = allocationQueue;

            // Clear the storage queue immediately to prevent the same tasks
            // from being executed again in a subsequent upkeep.
            delete allocationQueue;

            for (uint256 i = 0; i < queuedRequests.length; i++) {
                AllocationRequest memory request = queuedRequests[i];
                
                // Use a try-catch block to ensure that one failed allocation
                // does not prevent others from being processed.
                try this.allocateFunds(request.user, request.amount, request.strategy) {
                    // Success case. An event is already emitted by allocateFunds.
                } catch {
                    // Failure case. The allocation failed.
                    // You could add logic here to re-queue the request,
                    // or emit a specific "AllocationFailed" event.
                    // For this example, we simply let it fail and move on.
                }
            }
        }
    }

    // Fallback and receive functions to reject direct ETH transfers
    receive() external payable {
        revert("Vault does not accept ETH");
    }

    fallback() external payable {
        revert("Fallback: Vault does not accept ETH");
    }
}