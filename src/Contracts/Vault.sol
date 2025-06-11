// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../Interfaces/IStrategy.sol";
import "../Interfaces/IMockSwap.sol"; // Add this line

contract Vault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(address => uint256) public userDeposits;
    uint256 public totalValueLocked;
    IERC20 public usdc;
    IERC20 public usdy;
    address public admin;
    address public mockSwap;

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

    constructor(
        address _usdcAddress,
        address _usdyAddress,
        address _mockSwap,
        address _admin
    ) {
        require(_usdcAddress != address(0), "Invalid USDC address");
        require(_usdyAddress != address(0), "Invalid USDY address");
        require(_mockSwap != address(0), "Invalid MockSwap address");
        require(_admin != address(0), "Invalid admin address");

        admin = _admin;
        usdc = IERC20(_usdcAddress);
        usdy = IERC20(_usdyAddress);
        mockSwap = _mockSwap;
    }

    error NotAdmin();
    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        
        // Only accept USDY deposits
        usdy.safeTransferFrom(msg.sender, address(this), amount);
        
        // Immediately swap USDY to USDC
        usdy.approve(mockSwap, amount);
        uint256 usdcReceived = IMockSwap(mockSwap).swapUSDYtoUSDC(amount);
        
        userDeposits[msg.sender] += usdcReceived;
        totalValueLocked += usdcReceived;

        emit DepositSuccessful(msg.sender, usdcReceived);
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

    function swapUSDYtoUSDC(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(usdy.balanceOf(msg.sender) >= amount, "Insufficient USDY balance");

        // Transfer USDY from user to vault
        usdy.safeTransferFrom(msg.sender, address(this), amount);

        // Approve MockSwap to spend USDY
        usdy.safeApprove(mockSwap, amount);

        // Perform swap through MockSwap
        uint256 usdcReceived = IMockSwap(mockSwap).swapUSDYtoUSDC(amount);

        // Update user deposits and TVL
        userDeposits[msg.sender] += usdcReceived;
        totalValueLocked += usdcReceived;

        emit DepositSuccessful(msg.sender, usdcReceived);
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
