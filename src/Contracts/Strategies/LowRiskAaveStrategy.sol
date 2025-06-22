// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../Interfaces/IStrategy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IAavePool {
    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);

    function getUserAccountData(
        address user
    )
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

contract LowRiskAaveStrategy is IStrategy, Ownable, ReentrancyGuard {
    IERC20 public immutable usdc;
    address public immutable vault;
    IAavePool public immutable aavePool;

    constructor(address _usdc, address _aavePool, address _vault) {
        usdc = IERC20(_usdc);
        aavePool = IAavePool(_aavePool);
        vault = _vault;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function allocate(
        address,
        uint256 amount
    ) external override onlyVault nonReentrant {
        aavePool.supply(address(usdc), amount, address(this), 0);
    }

    function withdraw(
        uint256 amount
    ) external override onlyVault nonReentrant returns (uint256 loss) {
        uint256 before = usdc.balanceOf(address(this));

        // Get the max withdrawable amount (e.g., from balance in aToken or pool view)
        // Optional: add view to check balance if needed

        uint256 withdrawn;
        try aavePool.withdraw(address(usdc), amount, address(this)) returns (
            uint256 actualWithdrawn
        ) {
            withdrawn = actualWithdrawn;
        } catch {
            // If withdraw fails entirely, count it as full loss
            return amount;
        }

        uint256 afterBal = usdc.balanceOf(address(this));
        uint256 received = afterBal - before;

        // Sanity check: received might be less than asked
        if (received < amount) {
            loss = amount - received;
        } else {
            loss = 0;
        }

        return loss;
    }

    function approveSpending() public {
        IERC20(usdc).approve(address(aavePool), type(uint256).max);
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        (uint256 totalCollateral, , , , , ) = aavePool.getUserAccountData(
            address(this)
        );
        return totalCollateral;
    }

    function report()
        external
        view
        override
        onlyVault
        returns (uint256 gain, uint256 loss, uint256 debtPayment)
    {
        uint256 total = estimatedTotalAssets();
        return (total, 0, 0);
    }
}
