// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28; 
import "forge-std/Test.sol";
import "forge-std/Vm.sol"; 
import "../src/Contracts/StrategyManager.sol"; 


contract MockStrategy is IStrategy {
   
    address public immutable mockTokenAddress; 
    address public lastExecutedUser;
    uint256 public lastExecutedAmount;


    constructor(address _mockTokenAddress) {
        require(_mockTokenAddress != address(0), "MockStrategy: Invalid token address");
        mockTokenAddress = _mockTokenAddress;
    }

    function execute(address user, uint256 amount) external override {
        
        lastExecutedUser = user;
        lastExecutedAmount = amount;
    }

    
    function token() external view  returns (address) {
        return mockTokenAddress;
    }
}


// --- StrategyManager Test Contract ---
contract StrategyManagerTest is Test {
    
    StrategyManager public manager;
    MockStrategy public mockLowRiskStrategy;  
    MockStrategy public highRiskStrategy; 
  
    event StrategyChosen(address indexed user, address strategy);
    event LowRiskStrategyUpdated(address indexed oldStrategy, address indexed newStrategy);
    event HighRiskStrategyUpdated(address indexed oldStrategy, address indexed newStrategy);

    address public deployer; // This will be the owner/admin of StrategyManager
    address public user1;
    address public user2;
    address public stranger; // An address not involved in admin or user actions
    address public newOwnerCandidate; 

    function setUp() public {
        // Initialize test accounts with unique addresses
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        stranger = makeAddr("stranger");
        newOwnerCandidate = makeAddr("newOwnerCandidate");
        mockLowRiskStrategy = new MockStrategy(address(1));
        highRiskStrategy = new MockStrategy(address(2)); 
        vm.startPrank(deployer);
        manager = new StrategyManager(
            address(mockLowRiskStrategy),
            address(highRiskStrategy),    
            deployer                    
        );
        vm.stopPrank(); 
    }

    // --- Constructor Tests ---

    function test_ConstructorSetsInitialValuesCorrectly() public view {
        // Assert that the constructor correctly set the initial strategy addresses
        assertEq(manager.lowRiskStrategy(), address(mockLowRiskStrategy), "Low risk strategy not set correctly");
        assertEq(manager.highRiskStrategy(), address(highRiskStrategy), "High risk strategy not set correctly");
        // Assert that the deployer is the owner (from Ownable inheritance)
        assertEq(manager.owner(), deployer, "Deployer should be the owner");
    }

    function test_RevertWhen_ConstructorArgsAreZeroAddress() public {
        // Test case: _lowRisk is zero address
        vm.expectRevert("Invalid address"); 
        new StrategyManager(address(0), address(highRiskStrategy), deployer);

        // Test case: _highRisk is zero address
        vm.expectRevert("Invalid address");
        new StrategyManager(address(mockLowRiskStrategy), address(0), deployer);

        // Test case: _admin is zero address
        vm.expectRevert("Invalid address");
        new StrategyManager(address(mockLowRiskStrategy), address(highRiskStrategy), address(0));
    }


    // --- User Strategy Preference Tests ---

    function test_UserCanSetLowRiskStrategyPreference() public {
        vm.startPrank(user1); 
        vm.expectEmit(true, false, false, true); 
        emit StrategyChosen(user1, address(mockLowRiskStrategy));
        manager.setUserStrategy(address(mockLowRiskStrategy));
        vm.stopPrank();
        assertEq(manager.userStrategyChoice(user1), address(mockLowRiskStrategy), "User1's strategy choice should be low risk");
    }

    function test_UserCanSetHighRiskStrategyPreference() public {
        vm.startPrank(user2); 
        vm.expectEmit(true, false, false, true); 
        emit StrategyChosen(user2, address(highRiskStrategy));
        manager.setUserStrategy(address(highRiskStrategy));
        vm.stopPrank();
        assertEq(manager.userStrategyChoice(user2), address(highRiskStrategy), "User2's strategy choice should be high risk");
    }

    function test_RevertWhen_UserSetsInvalidStrategy() public {
        vm.startPrank(user1); 
        vm.expectRevert("Invalid strategy"); 
        manager.setUserStrategy(stranger); 
        vm.stopPrank();
    }


    // --- Admin-Only Strategy Update Tests ---

    function test_OwnerCanUpdateLowRiskStrategy() public {
        
        MockStrategy newMockLowRisk = new MockStrategy(address(3));
        address oldStrategyAddress = address(mockLowRiskStrategy); 

        vm.startPrank(deployer); 
        vm.expectEmit(true, true, false, false); 
        emit LowRiskStrategyUpdated(oldStrategyAddress, address(newMockLowRisk));
        manager.setLowRiskStrategy(address(newMockLowRisk));
        vm.stopPrank();

        // Assert that the low risk strategy address has been updated
        assertEq(manager.lowRiskStrategy(), address(newMockLowRisk), "Low risk strategy should be updated");
    }

    function test_RevertWhen_NonOwnerUpdatesLowRiskStrategy() public {
        MockStrategy newMockLowRisk = new MockStrategy(address(3));
        
        vm.startPrank(stranger); 
        vm.expectRevert("Ownable: caller is not the owner"); 
        manager.setLowRiskStrategy(address(newMockLowRisk));
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateLowRiskStrategyToZeroAddress() public {
        vm.startPrank(deployer); 
        vm.expectRevert("Invalid address"); 
        manager.setLowRiskStrategy(address(0));
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateLowRiskStrategyToHighRiskStrategy() public {
        vm.startPrank(deployer); 
        vm.expectRevert("Strategy already set as high risk"); 
        manager.setLowRiskStrategy(address(highRiskStrategy)); 
        vm.stopPrank();
    }

    function test_OwnerCanUpdateHighRiskStrategy() public {
        MockStrategy newMockHighRisk = new MockStrategy(address(4));
        address oldStrategyAddress = address(highRiskStrategy); 

        vm.startPrank(deployer); 
        vm.expectEmit(true, true, false, false); 
        emit HighRiskStrategyUpdated(oldStrategyAddress, address(newMockHighRisk));
        manager.setHighRiskStrategy(address(newMockHighRisk));
        vm.stopPrank();

        // Assert that the high risk strategy address has been updated
        assertEq(manager.highRiskStrategy(), address(newMockHighRisk), "High risk strategy should be updated");
    }

    function test_RevertWhen_NonOwnerUpdatesHighRiskStrategy() public {
        MockStrategy newMockHighRisk = new MockStrategy(address(4));

        vm.startPrank(stranger); // Simulate a non-owner calling
        vm.expectRevert("Ownable: caller is not the owner");
        manager.setHighRiskStrategy(address(newMockHighRisk));
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateHighRiskStrategyToZeroAddress() public {
        vm.startPrank(deployer); 
        vm.expectRevert("Invalid address");
        manager.setHighRiskStrategy(address(0));
        vm.stopPrank();
    }

    function test_RevertWhen_UpdateHighRiskStrategyToLowRiskStrategy() public {
        vm.startPrank(deployer); 
        vm.expectRevert("Strategy already set as low risk"); 
        manager.setHighRiskStrategy(address(mockLowRiskStrategy)); 
        vm.stopPrank();
    }

    // --- Getter Test ---

    function test_GetUserStrategyReturnsCorrectChoice() public {
        vm.startPrank(user1);
        manager.setUserStrategy(address(mockLowRiskStrategy));
        vm.stopPrank();

        vm.startPrank(user2);
        manager.setUserStrategy(address(highRiskStrategy));
        vm.stopPrank();

        assertEq(manager.getUserStrategy(user1), address(mockLowRiskStrategy), "getUserStrategy should return user1's choice");
        assertEq(manager.getUserStrategy(user2), address(highRiskStrategy), "getUserStrategy should return user2's choice");
        // Test for a user who hasn't set a preference (should return address(0))
        assertEq(manager.getUserStrategy(stranger), address(0), "getUserStrategy should return zero for unset user");
    }

}