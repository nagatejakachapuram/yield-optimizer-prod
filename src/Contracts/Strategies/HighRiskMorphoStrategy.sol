// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../../Interfaces/IStrategy.sol";
import "../../Interfaces/IMorpho.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract HighRiskMorphoStrategy is IStrategy, Ownable, ReentrancyGuard {
    address public immutable vault;
    IERC20 public immutable usdc;
    IMorpho public immutable morpho;
    address public immutable usdcMarket;

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

    modifier onlyVault() {
        require(msg.sender == vault, "Only vault");
        _;
    }

    function allocate(
        address,
        uint256 amount
    ) external override onlyVault nonReentrant {
        require(usdc.balanceOf(address(this)) >= amount, "Not enough USDC");
        morpho.supply(usdcMarket, amount, address(this));
    }

    function withdraw(
        uint256 amountNeeded
    ) external override onlyVault nonReentrant returns (uint256 loss) {
        uint256 beforeBalance = usdc.balanceOf(address(this));
        morpho.withdraw(usdcMarket, amountNeeded, address(this));
        uint256 afterBalance = usdc.balanceOf(address(this));
        return
            beforeBalance + amountNeeded > afterBalance
                ? amountNeeded - (afterBalance - beforeBalance)
                : 0;
    }

    function approveSpending() public  {
        IERC20(usdc).approve(address(morpho), type(uint256).max);
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        return morpho.balanceOf(usdcMarket, address(this));
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
