// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../Interfaces/AggregatorV3Interface.sol";

contract MockSwap {
    using SafeERC20 for IERC20;

    IERC20 public usdc;
    IERC20 public usdy;
    AggregatorV3Interface internal priceFeed;

    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant USDY_DECIMALS = 18;

    constructor(address _usdc, address _usdy, address _priceFeed) {
        require(_usdc != address(0), "Invalid USDC address");
        require(_usdy != address(0), "Invalid USDY address");
        require(_priceFeed != address(0), "Invalid price feed address");
        usdc = IERC20(_usdc);
        usdy = IERC20(_usdy);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getLatestPrice() public view returns (uint256) {
        (
            /* uint80 roundID */
            ,
            int256 price,
            /*uint startedAt*/
            ,
            /*uint timeStamp*/
            ,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }

    function swapUSDYtoUSDC(uint256 usdyAmount) external returns (uint256) {
        require(usdyAmount > 0, "Amount must be greater than 0");

        // Get USDY price from sender
        usdy.safeTransferFrom(msg.sender, address(this), usdyAmount);

        // Get latest USDC price from Chainlink and calculate USDC amount
        uint256 usdcPrice = getLatestPrice();
        uint256 usdcAmount = (usdyAmount * usdcPrice * 10 ** USDC_DECIMALS) / (10 ** USDY_DECIMALS * 10 ** 8); // Chainlink price feeds use 8 decimals

        // Check if we have enough USDC
        require(usdc.balanceOf(address(this)) >= usdcAmount, "Insufficient USDC liquidity");

        // Transfer USDC to sender
        usdc.safeTransfer(msg.sender, usdcAmount);

        return usdcAmount;
    }
}
