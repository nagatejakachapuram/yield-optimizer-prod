// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @notice Minimal Aave Pool interface required for deposits/withdrawals and data fetching
interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );
}

/// @title LowRiskAaveStrategy
/// @notice A low-risk yield strategy that supplies USDC into Aave V3
/// @dev Complies with IStrategy and is intended to be called only by a vault
contract LowRiskAaveStrategy is IStrategy, Ownable, ReentrancyGuard {
    /// @notice USDC token contract
    IERC20 public immutable usdc;

    /// @notice Vault address allowed to interact with this strategy
    address public immutable vault;

    /// @notice Aave pool contract for deposits/withdrawals
    IAavePool public immutable aavePool;

    /// @param _usdc The address of the USDC token
    /// @param _aavePool The address of the Aave V3 pool
    /// @param _vault The address of the vault using this strategy
    constructor(address _usdc, address _aavePool, address _vault) {
        usdc = IERC20(_usdc);
        aavePool = IAavePool(_aavePool);
        vault = _vault;
    }

    /// @dev Restricts access to only the vault
    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    /// @notice Allocates USDC to Aave by supplying to the lending pool
    /// @param amount Amount of USDC to supply
    /// @dev Vault must send USDC to this strategy before calling allocate
    function allocate(
        address, // ignored
        uint256 amount
    ) external override nonReentrant onlyVault {
        aavePool.supply(address(usdc), amount, address(this), 0);
    }

    /// @notice Withdraws USDC from Aave and returns any potential loss
    /// @param amount Amount requested by the vault to withdraw
    /// @return loss The difference between requested and received amount (if any)
    function withdraw(uint256 amount) external override nonReentrant onlyVault returns (uint256 loss) {
        uint256 before = usdc.balanceOf(address(this));

        uint256 withdrawn;
        try aavePool.withdraw(address(usdc), amount, address(this)) returns (uint256 actualWithdrawn) {
            withdrawn = actualWithdrawn;
        } catch {
            // Entire withdrawal failed, treat full amount as loss
            return amount;
        }

        uint256 afterBal = usdc.balanceOf(address(this));
        uint256 received = afterBal - before;

        // Calculate any shortfall as loss
        if (received < amount) {
            loss = amount - received;
        } else {
            loss = 0;
        }

        return loss;
    }

    /// @notice Approves Aave to spend unlimited USDC from this strategy
    /// @dev Must be called once before `allocate` can succeed
    function approveSpending() external {
        IERC20(usdc).approve(address(aavePool), type(uint256).max);
    }

    /// @notice Estimates total USDC assets currently deposited in Aave
    /// @return The total collateral value according to Aave (in base units)
    function estimatedTotalAssets() public view override returns (uint256) {
        (uint256 totalCollateral,,,,,) = aavePool.getUserAccountData(address(this));
        return totalCollateral;
    }

    /// @notice Returns strategy performance metrics to the vault
    /// @return gain Estimated gain (total collateral in Aave)
    /// @return loss Always 0 for now, as this strategy only tracks gains
    /// @return debtPayment Always 0 (not used in current design)
    function report() external view override onlyVault returns (uint256 gain, uint256 loss, uint256 debtPayment) {
        uint256 total = estimatedTotalAssets();
        return (total, 0, 0);
    }
}
