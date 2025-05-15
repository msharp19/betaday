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
    }
    
    function test_addConditionalSupportedAsset() public 
    {
        betADay.addConditionalSupportedAsset(MOCK_SUPPORTED_ASSET_1, MOCK_SUPPORTED_ASSET_ORACLE_1);

        assertTrue(betADay.isConditionalAssetSupported(MOCK_SUPPORTED_ASSET_1), "Market should exist");
        assertFalse(betADay.isConditionalAssetSupported(MOCK_SUPPORTED_ASSET_2), "Market should NOT exist");
    }

    function test_addMarket() public 
    {
        _addSupportedAssets();

        int256 movementPercent = 1000; // 10%
        uint256 betExpiry = block.timestamp + 48 hours;

        vm.prank(user1);

        uint256 marketId = betADay.addMarket(MOCK_SUPPORTED_ASSET_1, movementPercent, betExpiry);

        (int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address resolvedBy,
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout) = betADay.getMarket(marketId);

        assertEq(createdPrice, 150000000000, "Created price should be at 150000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 48h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(resolvedBy, address(0), "Resolved by should not be populated");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_1, "Condition asset should be MOCK_SUPPORTED_ASSET_1");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 1000 (10%)");
        assertEq(upTotalBets, 0, "There should be no up bets");
        assertEq(downTotalBets, 0, "There should be no down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
    }

    function test_addMarket_2() public 
    {
        _addSupportedAssets();

        int256 movementPercent = 2000; // 20%
        uint256 betExpiry = block.timestamp + 96 hours;

        vm.prank(user1);

        uint256 marketId = betADay.addMarket(MOCK_SUPPORTED_ASSET_2, movementPercent, betExpiry);

        (int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address resolvedBy,
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout) = betADay.getMarket(marketId);

        assertEq(createdPrice, 300000000000, "Created price should be at 300000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 96h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(resolvedBy, address(0), "Resolved by should not be populated");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_2, "Condition asset should be MOCK_SUPPORTED_ASSET_2");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 2000 (20%)");
        assertEq(upTotalBets, 0, "There should be no up bets");
        assertEq(downTotalBets, 0, "There should be no down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
    }

    function test_placeBet_up() public 
    {
        _addSupportedAssets();

        MockERC20(MOCK_ASSET).mint(user1, 2 ether);

        int256 movementPercent = 1000; // 10%
        uint256 betExpiry = block.timestamp + 48 hours;

        uint256 marketId = betADay.addMarket(MOCK_SUPPORTED_ASSET_1, movementPercent, betExpiry);

        vm.prank(user1);
        MockERC20(MOCK_ASSET).approve(address(betADay), 2 ether);

        vm.prank(user1);
        betADay.placeBet(marketId, true, 2 ether);

        (int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address resolvedBy,
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout) = betADay.getMarket(marketId);

        assertEq(createdPrice, 150000000000, "Created price should be at 150000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 48h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(resolvedBy, address(0), "Resolved by should not be populated");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_1, "Condition asset should be MOCK_SUPPORTED_ASSET_1");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 1000 (10%)");
        assertEq(upTotalBets, 2 ether, "There should be 2 ether in up bets");
        assertEq(downTotalBets, 0, "There should be no down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");

        (int256 userUpBetForMarket, int256 userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user1);
        assertEq(userUpBetForMarket, 2 ether, "The users up bet should equal 2 Ether");
        assertEq(userDownBetForMarket, 0, "The users down bet should equal 0 Ether");
    }

    function _addSupportedAssets() internal 
    {
        betADay.addConditionalSupportedAsset(MOCK_SUPPORTED_ASSET_1, MOCK_SUPPORTED_ASSET_ORACLE_1);
        betADay.addConditionalSupportedAsset(MOCK_SUPPORTED_ASSET_2, MOCK_SUPPORTED_ASSET_ORACLE_2);
    }
}
