// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../Interfaces/IStrategy.sol"; // Ensure this path is correct

contract MockStrategy is IStrategy {
    using SafeERC20 for IERC20;

    IERC20 public asset;
    address public vault;
    uint256 public totalInvested; // Tracks the *conceptual* amount the strategy holds/manages
    uint256 public fakeYield; // Amount of yield that will be *reported and transferred* as gain
    uint256 public mockLossToReport; // Added for testing loss reporting

    constructor(address _vault, address _asset) {
        vault = _vault;
        asset = IERC20(_asset);
    }

    modifier onlyVault() {
        require(msg.sender == vault, "Not vault");
        _;
    }

    function allocate(
        address _vault,
        uint256 amount
    ) external override onlyVault {
        require(_vault == vault, "Invalid vault");
        // The vault has already transferred `amount` to `address(this)` before calling allocate.
        // So we just update our internal tracking of what we *should* have managed.

        totalInvested += amount;
    }

    function estimatedTotalAssets() external view override returns (uint256) {
        // For a mock, this can just reflect its actual token balance for simplicity in testing.
        return asset.balanceOf(address(this));
    }

    function withdraw(
        uint256 amountNeeded
    ) external override onlyVault returns (uint256 loss) {
        uint256 currentBalance = asset.balanceOf(address(this));
        uint256 amountToTransfer = amountNeeded;
        loss = 0;

        if (currentBalance < amountNeeded) {
            amountToTransfer = currentBalance; // Can only withdraw what it has
            loss = amountNeeded - currentBalance; // The difference is a loss from strategy's perspective if it couldn't return enough
        }

        asset.safeTransfer(vault, amountToTransfer); // CRITICAL: Transfer tokens back to the vault
        totalInvested = totalInvested > amountToTransfer
            ? totalInvested - amountToTransfer
            : 0; // Update internal tracking

        return loss; // Return actual loss if couldn't meet demand
    }

    function report()
        external
        override
        onlyVault
        returns (uint256 gain, uint256 loss, uint256 debtPayment)
    {
        gain = fakeYield;
        loss = mockLossToReport;
        debtPayment = 0; // Not used by your YVault

        if (gain > 0) {
            // The strategy *transfers* the yield it has actually received to the vault.
            // This means `asset.balanceOf(address(this))` must have at least `gain` tokens for this to succeed.
            asset.safeTransfer(vault, gain);
        }
        // If there's a loss, the strategy doesn't transfer anything, it just reports it.
        // The vault will decrement its v_totalAssets based on this reported loss.

        fakeYield = 0; // Reset fake yield after reporting
        mockLossToReport = 0; // Reset mock loss after reporting
    }

    function setFakeYield(uint256 amount) external {
        fakeYield = amount;
    }

    function setMockLossToReport(uint256 amount) external {
        mockLossToReport = amount;
    }
}
