// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IStrategy} from "../../Interfaces/IStrategy.sol";

/// @title YVault - A simplified Yearn-style vault
/// @author
/// @notice This vault accepts a single ERC20 asset, mints shares, and allocates capital to an approved strategy.
/// @dev Only the vault owner can set strategy, allocate funds, or pull reports.
contract YVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice The underlying ERC20 asset accepted by the vault
    IERC20 public immutable asset;

    /// @notice Name of the vault (not ERC20 compatible)
    string public v_name;

    /// @notice Symbol of the vault (not ERC20 compatible)
    string public v_symbol;

    /// @notice The owner allowed to manage the vault and strategy
    address public vaultOwnerSafe;

    /// @notice Total assets under management (vault + strategy)
    uint256 public v_totalAssets;

    /// @notice Total shares issued to depositors
    uint256 public v_totalShares;

    /// @notice Mapping of user address to share balance
    mapping(address => uint256) public balanceOf;

    /// @notice ERC20-style allowance mapping (not actively used)
    mapping(address => mapping(address => uint256)) public allowance;

    /// @notice The current active yield strategy
    IStrategy public currentStrategy;

    /// @notice Emitted on deposit
    event VaultDeposit(address indexed user, uint256 assets, uint256 shares);

    /// @notice Emitted on withdrawal
    event VaultWithdraw(address indexed user, uint256 assets, uint256 shares);

    /// @notice Emitted when a strategy reports a gain/loss
    event VaultStrategyReported(
        uint256 gain,
        uint256 loss,
        uint256 totalAssets
    );

    /// @notice Emitted when the active strategy is updated
    event VaultStrategySet(address strategy);

    /// @notice Emitted when vault ownership is transferred
    event VaultOwnerTransferred(address newOwner);

    /// @notice Emitted when funds are allocated to a strategy
    event FundsAllocated(uint256 amount);

    // ---------- Custom Errors ---------- //
    error InsufficientVaultBalance();
    error ZeroAddress();
    error ZeroAmount();
    error NotVaultOwner();
    error InsufficientShares();
    error StrategyNotSet();
    error StrategyWithdrawalFailed();

    /// @notice Initializes the vault
    /// @param _token The ERC20 asset accepted by this vault
    /// @param _name The name of the vault
    /// @param _symbol The symbol of the vault
    /// @param _vaultOwnerSafe The address that can manage the vault
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

    /// @notice The Chainlink Automation Keeper address allowed to trigger upkeep
    address public chainlinkKeeper;

    /// @notice Only callable by the Chainlink keeper
    modifier onlyKeeper() {
        if (msg.sender != chainlinkKeeper) revert NotVaultOwner(); // reuse error or make new one
        _;
    }

    /// @notice Set or update the keeper address
    function setChainlinkKeeper(address _keeper) external onlyVaultOwner {
        if (_keeper == address(0)) revert ZeroAddress();
        chainlinkKeeper = _keeper;
    }

    /// @notice Restricts function to only the vault owner
    modifier onlyVaultOwner() {
        if (msg.sender != vaultOwnerSafe) revert NotVaultOwner();
        _;
    }

    /// @notice Transfers ownership of the vault to a new address
    /// @param newOwner The new owner address
    function transferVaultOwnership(address newOwner) external onlyVaultOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        vaultOwnerSafe = newOwner;
        emit VaultOwnerTransferred(newOwner);
    }

    /// @notice Sets a new strategy for the vault
    /// @param _strategy The address of the strategy contract
    function setStrategy(address _strategy) external onlyVaultOwner {
        if (_strategy == address(0)) revert ZeroAddress();
        currentStrategy = IStrategy(_strategy);
        emit VaultStrategySet(_strategy);
    }

    /// @notice Pulls gain/loss report from strategy and updates vault accounting
    function reportFromStrategy() external onlyVaultOwner {
        if (address(currentStrategy) == address(0)) revert StrategyNotSet();
        (uint256 gain, uint256 loss, ) = currentStrategy.report();

        if (gain > 0) {
            v_totalAssets += gain;
        } else if (loss > 0) {
            v_totalAssets = v_totalAssets > loss ? v_totalAssets - loss : 0;
        }

        emit VaultStrategyReported(gain, loss, v_totalAssets);
    }

    /// @notice Deposit tokens into the vault and receive vault shares
    /// @param amount The amount of tokens to deposit
    /// @return shares The number of shares minted
    function deposit(
        uint256 amount
    ) external nonReentrant returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();

        // Transfer in first
        asset.safeTransferFrom(msg.sender, address(this), amount);

        uint256 _totalAssets = v_totalAssets + amount; // include the newly transferred amount

        shares = (v_totalShares == 0)
            ? amount
            : (amount * v_totalShares) / v_totalAssets;

        if (shares == 0) revert InsufficientShares(); // extra safety

        balanceOf[msg.sender] += shares;
        v_totalShares += shares;
        v_totalAssets = _totalAssets; // update total assets **after** transfer

        emit VaultDeposit(msg.sender, amount, shares);
    }

    /// @notice Withdraw tokens by redeeming vault shares
    /// @param shares The number of shares to redeem
    /// @return amount The amount of assets withdrawn
    function withdraw(
        uint256 shares
    ) external nonReentrant returns (uint256 amount) {
        if (shares == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        // Calculate amount of assets to return
        amount = (shares * v_totalAssets) / v_totalShares;

        // Check vault balance before burning shares
        uint256 vaultBalance = asset.balanceOf(address(this));
        if (vaultBalance < amount) {
            uint256 shortfall = amount - vaultBalance;
            if (address(currentStrategy) == address(0)) revert StrategyNotSet();
            currentStrategy.withdraw(shortfall);

            // Re-check vault balance after strategy withdrawal
            vaultBalance = asset.balanceOf(address(this));
            if (vaultBalance < amount) {
                revert StrategyWithdrawalFailed(); // Optional custom error
            }
        }

        // Burn shares AFTER we’re sure we can return funds
        balanceOf[msg.sender] -= shares;
        v_totalShares -= shares;

        asset.safeTransfer(msg.sender, amount);
        v_totalAssets -= amount;
        emit VaultWithdraw(msg.sender, amount, shares);
    }

    /// @notice Allocates vault funds to the active strategy
    /// @param amount The amount of tokens to allocate
    function allocateFunds(uint256 amount) external onlyKeeper {
        if (amount > asset.balanceOf(address(this)))
            revert InsufficientVaultBalance();
        if (address(currentStrategy) == address(0)) revert StrategyNotSet();

        asset.safeTransfer(address(currentStrategy), amount);
        currentStrategy.allocate(address(this), amount);

        emit FundsAllocated(amount);
    }

    /// @notice Returns the current price per share in 1e18 precision
    /// @return The value of 1 share in terms of underlying asset
    function getPricePerShare() public view returns (uint256) {
        return
            (v_totalShares == 0)
                ? 1e18
                : (v_totalAssets * 1e18) / v_totalShares;
    }

    /// @notice Returns total assets under vault management
    /// @return Total assets including both vault and strategy
    function totalAssets() public view returns (uint256) {
        return
            asset.balanceOf(address(this)) +
            currentStrategy.estimatedTotalAssets();
    }

    /// @notice Verifies that the vault accounting matches real balances
    /// @return isConsistent Whether actual reserves match accounting
    /// @return actualAssets Sum of vault and strategy balances
    /// @return expectedAssets The vault's recorded totalAssets
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

    /// @notice Allows Chainlink Automation to pull a report from the strategy
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
}
