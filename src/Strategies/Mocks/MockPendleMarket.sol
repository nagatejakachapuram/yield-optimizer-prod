// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

// Mock PT token
contract MockPT is ERC20Burnable {
    constructor() ERC20("Mock PT", "PT") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock YT token
contract MockYT is ERC20Burnable {
    constructor() ERC20("Mock YT", "YT") {}
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockPendleMarket {
    address public immutable USDC;
    MockPT public immutable ptToken;
    MockYT public immutable ytToken;

    mapping(address => uint256) public depositTime;
    mapping(address => uint256) public claimedYield;
    uint256 public apyBasisPoints;

    event MarketDeposited(address indexed user, uint256 amount);
    event PTWithdrawn(address indexed user, uint256 amount);
    event YieldClaimed(address indexed user, uint256 amount);

    constructor(address _usdc, address _pt, address _yt, uint256 _apyBasisPoints) {
        USDC = _usdc;
        ptToken = MockPT(_pt);
        ytToken = MockYT(_yt);
        apyBasisPoints = _apyBasisPoints;
    }

    function depositMarket(address market, uint256 amount, address receiver) external {
        require(market == USDC, "Only USDC supported");
        require(amount > 0, "Amount must be > 0");

        IERC20(USDC).transferFrom(msg.sender, address(this), amount);

        ptToken.mint(receiver, amount);
        ytToken.mint(receiver, amount);
        depositTime[receiver] = block.timestamp;

        emit MarketDeposited(receiver, amount);
    }

    function redeemPT(uint256 amount) external {
        require(amount > 0, "Nothing to redeem");

        ptToken.burnFrom(msg.sender, amount);
        IERC20(USDC).transfer(msg.sender, amount);

        emit PTWithdrawn(msg.sender, amount);
    }

    function claimYield() external {
        uint256 ytBalance = ytToken.balanceOf(msg.sender);
        require(ytBalance > 0, "No YT tokens");

        uint256 timeHeld = block.timestamp - depositTime[msg.sender];
        uint256 totalYield = (ytBalance * apyBasisPoints * timeHeld) / (365 days * 10000);
        uint256 yieldToClaim = totalYield - claimedYield[msg.sender];

        require(yieldToClaim > 0, "No yield available");
        claimedYield[msg.sender] += yieldToClaim;

        ytToken.burnFrom(msg.sender, ytBalance);
        IERC20(USDC).transfer(msg.sender, yieldToClaim);

        emit YieldClaimed(msg.sender, yieldToClaim);
    }
}
