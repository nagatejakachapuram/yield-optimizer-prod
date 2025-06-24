// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IStrategy} from "../../Interfaces/IStrategy.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";


/// @title YVault - A simplified Yearn-style vault
/// @author
/// @notice Accepts a single ERC20 token, mints vault shares, and allocates funds to an external strategy.
/// @dev Compatible with Chainlink Automation via keeper, and includes pausability, reentrancy protection, and ERC20-style interface (limited).
contract YVault is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // ========== Vault Metadata ==========

    /// @notice The ERC20 asset accepted by the vault
    IERC20 public immutable asset;

    /// @notice The vault name (non-ERC20 standard)
    string public v_name;

    /// @notice The vault symbol (non-ERC20 standard)
    string public v_symbol;

    /// @notice The address with permission to manage the vault and set strategy
    address public vaultOwnerSafe;

    /// @notice The total amount of assets under vault management (vault + strategy)
    uint256 public v_totalAssets;

    /// @notice The total number of shares issued by the vault
    uint256 public v_totalShares;

    /// @notice Mapping of user address to their vault share balance
    mapping(address => uint256) public balanceOf;

    /// @notice ERC20-style allowance mapping (not actively used)
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice The currently active yield strategy
    IStrategy public currentStrategy;

    /// @notice The address of Chainlink Automation keeper
    address public chainlinkKeeper;

    // ========== Events ==========

    /// @notice Emitted on deposit
    event VaultDeposit(address indexed user, uint256 assets, uint256 shares);

    /// @notice Emitted on withdrawal
    event VaultWithdraw(address indexed user, uint256 assets, uint256 shares);

    /// @notice Emitted when a strategy reports gain/loss
    event VaultStrategyReported(uint256 gain, uint256 loss, uint256 totalAssets);

    /// @notice Emitted when strategy is updated
    event VaultStrategySet(address strategy);

    /// @notice Emitted on vault ownership transfer
    event VaultOwnerTransferred(address newOwner);

    /// @notice Emitted when funds are allocated to a strategy
    event FundsAllocated(uint256 amount);

    // ========== Custom Errors ==========

    /// @notice Thrown when vault lacks funds to allocate or withdraw
    error InsufficientVaultBalance();

    /// @notice Thrown when a zero address is passed where not allowed
    error ZeroAddress();

    /// @notice Thrown when amount provided is zero
    error ZeroAmount();

    /// @notice Thrown when caller is not the vault owner
    error NotVaultOwner();

    /// @notice Thrown when user attempts to withdraw or burn more shares than they hold
    error InsufficientShares();

    /// @notice Thrown when a strategy interaction is attempted but no strategy is set
    error StrategyNotSet();

    /// @notice Thrown when a strategy fails to return funds to the vault
    error StrategyWithdrawalFailed();

    /// @notice Thrown when a non-keeper attempts to perform keeper-only action
    error NotChainlinkKeeper();

    // ========== Modifiers ==========

    /// @notice Restricts function to the vault owner
    modifier onlyVaultOwner() {
        if (msg.sender != vaultOwnerSafe) revert NotVaultOwner();
        _;
    }

    /// @notice Restricts function to Chainlink keeper
    modifier onlyKeeper() {
        if (msg.sender != chainlinkKeeper) revert NotVaultOwner(); // reusing error
        _;
    }

    // ========== Constructor ==========

    /// @notice Constructs the YVault
    /// @param _token The ERC20 asset the vault accepts
    /// @param _name The name of the vault
    /// @param _symbol The symbol of the vault
    /// @param _vaultOwnerSafe The vault owner address
    constructor(
        address _token,
        string memory _name,
        string memory _symbol,
        address _vaultOwnerSafe
    ) {
        if (_token == address(0)) revert ZeroAddress();
        if (_vaultOwnerSafe == address(0)) revert ZeroAddress();

        asset = IERC20(_token);
        v_name = _name;
        v_symbol = _symbol;
        vaultOwnerSafe = _vaultOwnerSafe;
    }

    // ========== Owner Functions ==========

    /// @notice Sets or updates the Chainlink keeper address
    /// @param _keeper The address of the keeper
    function setChainlinkKeeper(address _keeper) external onlyVaultOwner {
        if (_keeper == address(0)) revert NotChainlinkKeeper();
        chainlinkKeeper = _keeper;
    }

    /// @notice Transfers vault ownership to a new address
    /// @param newOwner The new owner address
    function transferVaultOwnership(address newOwner) external onlyVaultOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        vaultOwnerSafe = newOwner;
        emit VaultOwnerTransferred(newOwner);
    }

    /// @notice Sets the strategy for the vault
    /// @param _strategy The address of the new strategy contract
    function setStrategy(address _strategy) external onlyVaultOwner {
        if (_strategy == address(0)) revert ZeroAddress();
        currentStrategy = IStrategy(_strategy);
        emit VaultStrategySet(_strategy);
    }

    
    /// @notice Pauses the vault (stops deposit/withdraw/allocate)
    function pause() external onlyVaultOwner {
        _pause();
    }

    /// @notice Unpauses the vault
    function unpause() external onlyVaultOwner {
        _unpause();
    }

    // ========== Core Functions ==========

    /// @notice Deposits assets into the vault and mints shares
    /// @param amount The amount of asset to deposit
    /// @return shares Number of shares minted
    function deposit(
        uint256 amount
    ) external nonReentrant whenNotPaused returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();

        asset.safeTransferFrom(msg.sender, address(this), amount);

        uint256 _totalAssets = v_totalAssets + amount;

        shares = (v_totalShares == 0)
            ? amount
            : (amount * v_totalShares) / v_totalAssets;

        if (shares == 0) revert InsufficientShares();

        balanceOf[msg.sender] += shares;
        v_totalShares += shares;
        v_totalAssets = _totalAssets;

        emit VaultDeposit(msg.sender, amount, shares);
    }

    /// @notice Withdraws assets from the vault by burning shares
    /// @param shares The number of shares to redeem
    /// @return amount The amount of asset returned
    function withdraw(
        uint256 shares
    ) external nonReentrant whenNotPaused returns (uint256 amount) {
        if (shares == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        amount = (shares * v_totalAssets) / v_totalShares;

        uint256 vaultBalance = asset.balanceOf(address(this));
        if (vaultBalance < amount) {
            uint256 shortfall = amount - vaultBalance;
            if (address(currentStrategy) == address(0)) revert StrategyNotSet();
            currentStrategy.withdraw(shortfall);
            vaultBalance = asset.balanceOf(address(this));
            if (vaultBalance < amount) revert StrategyWithdrawalFailed();
        }

        balanceOf[msg.sender] -= shares;
        v_totalShares -= shares;

        asset.safeTransfer(msg.sender, amount);
        v_totalAssets -= amount;

        emit VaultWithdraw(msg.sender, amount, shares);
    }



    // ========== View Functions ==========

    /// @notice Returns the value of 1 share in terms of underlying asset
    /// @return The price per share (1e18 precision)
    function getPricePerShare() public view returns (uint256) {
        return
            (v_totalShares == 0)
                ? 1e18
                : (v_totalAssets * 1e18) / v_totalShares;
    }

    /// @notice Returns total assets managed by vault + strategy
    /// @return Total underlying assets
    function totalAssets() public view returns (uint256) {
        return
            asset.balanceOf(address(this)) +
            currentStrategy.estimatedTotalAssets();
    }

    /// @notice Verifies internal accounting matches real balances
    /// @return isConsistent True if balances match or exceed accounting
    /// @return actualAssets Sum of vault + strategy token balances
    /// @return expectedAssets The vault's internally recorded assets
    function verifyReserves()
        external
        view
        returns (
            bool isConsistent,
            uint256 actualAssets,
            uint256 expectedAssets
        )
    {
        uint256 vaultBal = asset.balanceOf(address(this));
        uint256 stratBal = address(currentStrategy) != address(0)
            ? currentStrategy.estimatedTotalAssets()
            : 0;

        actualAssets = vaultBal + stratBal;
        expectedAssets = v_totalAssets;

        isConsistent = (actualAssets >= expectedAssets);
    }

    /// @notice Chainlink keeper-triggered report to update accounting
    function reportIfNeeded() external onlyKeeper {
        if (address(currentStrategy) == address(0)) revert StrategyNotSet();
        (uint256 gain, uint256 loss, ) = currentStrategy.report();

        if (gain > 0) {
            v_totalAssets += gain;
        } else if (loss > 0) {
            v_totalAssets = v_totalAssets > loss ? v_totalAssets - loss : 0;
        }

        emit VaultStrategyReported(gain, loss, v_totalAssets);
    }

    /// @notice Allows recovery of non-core ERC20 tokens accidentally sent to vault
    /// @param token The token address to recover
    /// @param to Recipient of the recovered tokens
    /// @param amount Amount to recover
    function recoverERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyVaultOwner {
        if (token == address(asset)) revert(); // protect core asset
        if (to == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(to, amount);
    }

       // ========== Automation Functions ==========

           /// @notice Updates accounting by pulling report from current strategy
    function reportFromStrategy() internal {
        if (address(currentStrategy) == address(0)) revert StrategyNotSet();
        (uint256 gain, uint256 loss, ) = currentStrategy.report();

        if (gain > 0) {
            v_totalAssets += gain;
        } else if (loss > 0) {
            v_totalAssets = v_totalAssets > loss ? v_totalAssets - loss : 0;
        }

        emit VaultStrategyReported(gain, loss, v_totalAssets);
    }

        /// @notice Allocates funds from the vault to the active strategy
    /// @param amount The amount to allocate
    function allocateFunds(uint256 amount) internal whenNotPaused {
        if (amount > asset.balanceOf(address(this)))
            revert InsufficientVaultBalance();
        if (address(currentStrategy) == address(0)) revert StrategyNotSet();

        asset.safeTransfer(address(currentStrategy), amount);
        currentStrategy.allocate(address(this), amount);

        emit FundsAllocated(amount);
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory performData) {
        // Automation 1: Allocate idle funds
        uint256 idleFunds = asset.balanceOf(address(this));
        bool shouldAllocate = idleFunds > 0 && address(currentStrategy) != address(0);
        
        // Automation 2: Report from strategy (e.g., check every 24 hours)
        // Note: A real implementation might have more complex logic here.
        // For simplicity, we assume we want to report periodically.
        // This check can be enhanced to be based on time, profit, or other metrics.
        bool shouldReport = address(currentStrategy) != address(0);

        upkeepNeeded = shouldAllocate || shouldReport;
        
        // Encode which function to call in performUpkeep
        if (shouldAllocate) {
            performData = abi.encodeWithSelector(this.allocateFunds.selector, idleFunds);
        } else if (shouldReport) {
            performData = abi.encodeWithSelector(this.reportFromStrategy.selector);
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        // We decode the performData to call the correct function
        (bool success, ) = address(this).call(performData);
        require(success, "PerformUpkeep failed");
    }



}
    
