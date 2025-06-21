// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IStrategy} from "../../Interfaces/IStrategy.sol";

/// @title YVault - A simplified Yearn-style vault
contract YVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;

    string public vaultName;
    string public vaultSymbol;

    address public vaultOwnerSafe;

    uint256 public totalAssetsCached;
    uint256 public totalShares;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IStrategy public currentStrategy;

    event VaultDeposit(address indexed user, uint256 assets, uint256 shares);
    event VaultWithdraw(address indexed user, uint256 assets, uint256 shares);
    event VaultStrategyReported(uint256 gain, uint256 loss, uint256 totalAssets);
    event VaultStrategySet(address strategy);
    event VaultOwnerTransferred(address newOwner);
    event FundsAllocated(uint256 amount);

    error InsufficientVaultBalance();
    error ZeroAddress();
    error ZeroAmount();
    error NotVaultOwner();
    error InsufficientShares();
    error StrategyNotSet();

    constructor(
        address _token,
        string memory _name,
        string memory _symbol,
        address _vaultOwnerSafe
    ) {
        if (_token == address(0) || _vaultOwnerSafe == address(0)) revert ZeroAddress();

        asset = IERC20(_token);
        vaultName = _name;
        vaultSymbol = _symbol;
        vaultOwnerSafe = _vaultOwnerSafe;
    }

    modifier onlyVaultOwner() {
        if (msg.sender != vaultOwnerSafe) revert NotVaultOwner();
        _;
    }

    function transferVaultOwnership(address newOwner) external onlyVaultOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        vaultOwnerSafe = newOwner;
        emit VaultOwnerTransferred(newOwner);
    }

    function setStrategy(address _strategy) external onlyVaultOwner {
        if (_strategy == address(0)) revert ZeroAddress();
        currentStrategy = IStrategy(_strategy);
        emit VaultStrategySet(_strategy);
    }

    function reportFromStrategy() external onlyVaultOwner {
        if (address(currentStrategy) == address(0)) revert StrategyNotSet();
        (uint256 gain, uint256 loss, ) = currentStrategy.report();

        unchecked {
            if (gain > 0) {
                totalAssetsCached += gain;
            } else if (loss > 0) {
                totalAssetsCached = totalAssetsCached > loss ? totalAssetsCached - loss : 0;
            }
        }

        emit VaultStrategyReported(gain, loss, totalAssetsCached);
    }

    function deposit(uint256 amount) external nonReentrant returns (uint256 shares) {
        if (amount == 0) revert ZeroAmount();

        shares = _convertToShares(amount);
        if (shares == 0) revert ZeroAmount();

        balanceOf[msg.sender] += shares;
        totalShares += shares;
        totalAssetsCached += amount;

        asset.safeTransferFrom(msg.sender, address(this), amount);

        emit VaultDeposit(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) external nonReentrant returns (uint256 amount) {
        if (shares == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < shares) revert InsufficientShares();

        amount = _convertToAssets(shares);

        balanceOf[msg.sender] -= shares;
        totalShares -= shares;

        uint256 vaultBal = asset.balanceOf(address(this));
        if (vaultBal < amount) {
            uint256 shortfall = amount - vaultBal;
            if (address(currentStrategy) == address(0)) revert StrategyNotSet();
            currentStrategy.withdraw(shortfall);

            uint256 newBal = asset.balanceOf(address(this));
            amount = newBal >= amount ? amount : newBal;
        }

        totalAssetsCached = totalAssetsCached >= amount ? totalAssetsCached - amount : 0;

        asset.safeTransfer(msg.sender, amount);
        emit VaultWithdraw(msg.sender, amount, shares);
    }

    function allocateFunds(uint256 amount) external onlyVaultOwner {
        if (amount > asset.balanceOf(address(this))) revert InsufficientVaultBalance();
        if (address(currentStrategy) == address(0)) revert StrategyNotSet();

        totalAssetsCached -= amount;

        asset.safeTransfer(address(currentStrategy), amount);
        currentStrategy.allocate(address(this), amount);

        emit FundsAllocated(amount);
    }

    function getPricePerShare() public view returns (uint256) {
        return (totalShares == 0) ? 1e18 : (totalAssetsCached * 1e18) / totalShares;
    }

    function totalAssets() public view returns (uint256) {
        return totalAssetsCached;
    }

    function totalSupply() external view returns (uint256) {
        return totalShares;
    }

    function verifyReserves()
        external
        view
        returns (bool isConsistent, uint256 actualAssets, uint256 expectedAssets)
    {
        uint256 vaultBal = asset.balanceOf(address(this));
        uint256 stratBal = address(currentStrategy) != address(0)
            ? currentStrategy.estimatedTotalAssets()
            : 0;

        actualAssets = vaultBal + stratBal;
        expectedAssets = totalAssetsCached;
        isConsistent = actualAssets >= expectedAssets;
    }

    function _convertToShares(uint256 assets) internal view returns (uint256) {
        return (totalShares == 0) ? assets : (assets * totalShares) / totalAssetsCached;
    }

    function _convertToAssets(uint256 shares) internal view returns (uint256) {
        return (totalShares == 0) ? 0 : (shares * totalAssetsCached) / totalShares;
    }
}
