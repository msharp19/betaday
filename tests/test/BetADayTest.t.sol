// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@betaday/BetADay.sol";
import "@betaday/MockERC20.sol";
import "@betaday/MockOracle.sol";

import {Test, console} from "forge-std/Test.sol";

contract BetADayTest is Test {
    BetADay public betADay;
    address houseRakeReceiver;
    address user1;
    address user2;
    address user3;
    address MOCK_ASSET;

    function setUp() public 
    {
        // Setup user addresses
        admin = address(this); // Test contract is admin
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        // Mock asset
        MOCK_ASSET = address(new MockERC20("TEST","TEST", 6));

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
        
    }
    
    
    function test_do(uint256 x) public {
        //counter.setNumber(x);
        //assertEq(counter.number(), x);
    }
}
