// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../Interfaces/IStrategy.sol";
import "../../Interfaces/IMorpho.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title HighRiskMorphoStrategy
/// @notice A high-risk yield strategy that supplies USDC into a Morpho market
/// @dev Designed for integration with a vault and the Morpho lending protocol
contract HighRiskMorphoStrategy is IStrategy, Ownable, ReentrancyGuard {
    /// @notice The vault contract allowed to interact with this strategy
    address public immutable vault;

    /// @notice The USDC token being supplied to Morpho
    IERC20 public immutable usdc;

    /// @notice Morpho protocol interface
    IMorpho public immutable morpho;

    /// @notice The Morpho market for USDC (could be CompoundV3 or AaveV3 wrapper)
    address public immutable usdcMarket;

    /// @param _usdc The address of the USDC token
    /// @param _morpho The address of the Morpho protocol contract
    /// @param _usdcMarket The Morpho market address for USDC
    /// @param _vault The vault address using this strategy
    constructor(
        address _usdc,
        address _morpho,
        address _usdcMarket,
        address _vault
    ) {
        require(
            _usdc != address(0) &&
                _morpho != address(0) &&
                _usdcMarket != address(0) &&
                _vault != address(0),
            "Invalid address"
        );
        usdc = IERC20(_usdc);
        morpho = IMorpho(_morpho);
        usdcMarket = _usdcMarket;
        vault = _vault;
    }

    /// @dev Restricts function to be called only by the vault
    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    /// @notice Supplies USDC into the Morpho market
    /// @param amount The amount of USDC to allocate (must already be in this strategy)
    function allocate(
        address, // unused
        uint256 amount
    ) external override onlyVault nonReentrant {
        require(usdc.balanceOf(address(this)) >= amount, "Not enough USDC");
        morpho.supply(usdcMarket, amount, address(this));
    }

    /// @notice Withdraws USDC from Morpho
    /// @param amountNeeded The amount requested to be withdrawn by the vault
    /// @return loss The difference between expected and actual USDC received (if any)
    function withdraw(
        uint256 amountNeeded
    ) external override onlyVault nonReentrant returns (uint256 loss) {
        uint256 beforeBalance = usdc.balanceOf(address(this));
        morpho.withdraw(usdcMarket, amountNeeded, address(this));
        uint256 afterBalance = usdc.balanceOf(address(this));

        uint256 actualReceived = afterBalance - beforeBalance;

        if (actualReceived < amountNeeded) {
            loss = amountNeeded - actualReceived;
        } else {
            loss = 0;
        }

        return loss;
    }

    /// @notice Approves Morpho to spend USDC from this strategy
    /// @dev Must be called once before `allocate` can succeed
    function approveSpending() public {
        IERC20(usdc).approve(address(morpho), type(uint256).max);
    }

    /// @notice Returns the total USDC currently supplied in the Morpho market
    /// @return The total balance (including interest) held in Morpho
    function estimatedTotalAssets() public view override returns (uint256) {
        return morpho.balanceOf(usdcMarket, address(this));
    }

    /// @notice Reports the current asset balance to the vault
    /// @dev Gain is the full balance reported, loss and debtPayment are unused
    /// @return gain Current total balance in Morpho
    /// @return loss Always 0
    /// @return debtPayment Always 0
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
