// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@betaday/BetADay.sol";
import "@betaday-mocks/MockERC20.sol";
import "@betaday-mocks/MockOracle.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Test, console} from "forge-std/Test.sol";

contract BetADayTest is Test 
{
    BetADay public betADay;
    
    address houseRakeReceiver;
    address admin;
    address user1;
    address user2;
    address user3;

    address MOCK_ASSET;
    address MOCK_SUPPORTED_ASSET_1;
    address MOCK_SUPPORTED_ASSET_2;
    address MOCK_SUPPORTED_ASSET_ORACLE_1;
    address MOCK_SUPPORTED_ASSET_ORACLE_2;

    function setUp() public 
    {
        // Setup user addresses
        admin = address(this); // Test contract is admin
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);
        houseRakeReceiver = address(0x4);

        // Mocks
        MOCK_ASSET = address(new MockERC20("TEST","TEST", 6));
        MOCK_SUPPORTED_ASSET_1 = address(0x5);
        MOCK_SUPPORTED_ASSET_2 = address(0x6);
        MOCK_SUPPORTED_ASSET_ORACLE_1 = address(new MockOracle(150000000000)); // 1500 USD (minus 10^8)
        MOCK_SUPPORTED_ASSET_ORACLE_2 = address(new MockOracle(300000000000)); // 3000 USD (minus 10^8)

        // Deploy implementation & proxy for it
        BetADay implementation = new BetADay();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                BetADay.initialize.selector,
                MOCK_ASSET,
                1000, // 10% (minimum)
                houseRakeReceiver,
                1000 // 10% (minimum)
            )
        );

        betADay = BetADay(address(proxy));

        // Add supported tokens
        betADay.addConditionalSupportedAsset(MOCK_SUPPORTED_ASSET_1, MOCK_SUPPORTED_ASSET_ORACLE_1);
        betADay.addConditionalSupportedAsset(MOCK_SUPPORTED_ASSET_2, MOCK_SUPPORTED_ASSET_ORACLE_2);
    }
    
    
    function test_do(uint256 x) public {
        //counter.setNumber(x);
        //assertEq(counter.number(), x);

        
    }
}
