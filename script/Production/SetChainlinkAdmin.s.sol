//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import "forge-std/Script.sol";
import "../../src/Contracts/Vault.sol";

contract SetChainlinkAdmin is Script {

    address constant CHAINLINK_AUTOMATION_ADMIN_ADDRESS = 0x0af700A3026adFddC10f7Aa8Ba2419e8503592f7;
    address public vaultAddress = 0xA559DE0B91eE49f7175CBcEA110e7cbfF6684bF2;
    Vault public vault;
    
    function setup() public {

        vault = Vault(payable(vaultAddress));

        console.log("Settting chainlink admin");

        vault.setChainlinkAdmin(CHAINLINK_AUTOMATION_ADMIN_ADDRESS);
        console.log("Set Chainlink Admin in Vault to:", CHAINLINK_AUTOMATION_ADMIN_ADDRESS);

    } 

    function run() public {

        vault.setChainlinkAdmin(CHAINLINK_AUTOMATION_ADMIN_ADDRESS);
        console.log("Set Chainlink Admin in Vault to:", CHAINLINK_AUTOMATION_ADMIN_ADDRESS);

    }

}