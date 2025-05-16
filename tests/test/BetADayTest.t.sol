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
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout,
        int256 resolvedPrice) = betADay.getMarket(marketId);

        assertEq(createdPrice, 150000000000, "Created price should be at 150000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 48h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_1, "Condition asset should be MOCK_SUPPORTED_ASSET_1");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 1000 (10%)");
        assertEq(upTotalBets, 0, "There should be no up bets");
        assertEq(downTotalBets, 0, "There should be no down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
        assertEq(resolvedPrice, 0 ether, "Resolved price should be 0 ether");
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
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout,
        int256 resolvedPrice) = betADay.getMarket(marketId);

        assertEq(createdPrice, 300000000000, "Created price should be at 300000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 96h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_2, "Condition asset should be MOCK_SUPPORTED_ASSET_2");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 2000 (20%)");
        assertEq(upTotalBets, 0, "There should be no up bets");
        assertEq(downTotalBets, 0, "There should be no down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
        assertEq(resolvedPrice, 0 ether, "Resolved price should be 0 ether");
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
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout,
        int256 resolvedPrice) = betADay.getMarket(marketId);

        assertEq(createdPrice, 150000000000, "Created price should be at 150000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 48h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_1, "Condition asset should be MOCK_SUPPORTED_ASSET_1");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 1000 (10%)");
        assertEq(upTotalBets, 2 ether, "There should be 2 ether in up bets");
        assertEq(downTotalBets, 0, "There should be no down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
        assertEq(resolvedPrice, 0 ether, "Resolved price should be 0 ether");

        (int256 userUpBetForMarket, int256 userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user1);
        assertEq(userUpBetForMarket, 2 ether, "The users up bet should equal 2 Ether");
        assertEq(userDownBetForMarket, 0, "The users down bet should equal 0 Ether");
    }

    function test_placeBet_down() public 
    {
        _addSupportedAssets();

        MockERC20(MOCK_ASSET).mint(user1, 4 ether);

        int256 movementPercent = 1000; // 10%
        uint256 betExpiry = block.timestamp + 48 hours;

        uint256 marketId = betADay.addMarket(MOCK_SUPPORTED_ASSET_2, movementPercent, betExpiry);

        vm.prank(user1);
        MockERC20(MOCK_ASSET).approve(address(betADay), 4 ether);

        vm.prank(user1);
        betADay.placeBet(marketId, false, 1 ether);

        vm.prank(user1);
        betADay.placeBet(marketId, false, 3 ether);

        (int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout,
        int256 resolvedPrice) = betADay.getMarket(marketId);

        assertEq(createdPrice, 300000000000, "Created price should be at 300000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 48h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_2, "Condition asset should be MOCK_SUPPORTED_ASSET_2");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 1000 (10%)");
        assertEq(downTotalBets, 4 ether, "There should be 4 ether in down bets");
        assertEq(upTotalBets, 0, "There should be no up bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
        assertEq(resolvedPrice, 0 ether, "Resolved price should be 0 ether");

        (int256 userUpBetForMarket, int256 userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user1);
        assertEq(userUpBetForMarket, 0, "The users up bet should equal0 Ether");
        assertEq(userDownBetForMarket, 4 ether, "The users down bet should equal 4 Ether");
    }

    function test_placeBet_multiUser() public 
    {
        _addSupportedAssets();

        MockERC20(MOCK_ASSET).mint(user1, 2 ether);
        MockERC20(MOCK_ASSET).mint(user2, 4 ether);
        MockERC20(MOCK_ASSET).mint(user3, 1 ether);

        int256 movementPercent = 2000; // 20%
        uint256 betExpiry = block.timestamp + 100 hours;

        uint256 marketId = betADay.addMarket(MOCK_SUPPORTED_ASSET_1, movementPercent, betExpiry);

        vm.prank(user1);
        MockERC20(MOCK_ASSET).approve(address(betADay), 2 ether);

        vm.prank(user2);
        MockERC20(MOCK_ASSET).approve(address(betADay), 4 ether);

        vm.prank(user3);
        MockERC20(MOCK_ASSET).approve(address(betADay), 1 ether);

        vm.prank(user1);
        betADay.placeBet(marketId, true, 2 ether);

        vm.prank(user2);
        betADay.placeBet(marketId, true, 4 ether);

        vm.prank(user3);
        betADay.placeBet(marketId, true, 1 ether);

        (int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout,
        int256 resolvedPrice) = betADay.getMarket(marketId);

        assertEq(createdPrice, 150000000000, "Created price should be at 150000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 48h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_1, "Condition asset should be MOCK_SUPPORTED_ASSET_1");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 2000 (20%)");
        assertEq(upTotalBets, 7 ether, "There should be 7 ether in up bets");
        assertEq(downTotalBets, 0, "There should be no down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
        assertEq(resolvedPrice, 0 ether, "Resolved price should be 0 ether");

        (int256 userUpBetForMarket, int256 userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user1);
        assertEq(userUpBetForMarket, 2 ether, "The user1s up bet should equal 2 Ether");
        assertEq(userDownBetForMarket, 0, "The user1s down bet should equal 0 Ether");

        (userUpBetForMarket, userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user2);
        assertEq(userUpBetForMarket, 4 ether, "The user2s up bet should equal 4 Ether");
        assertEq(userDownBetForMarket, 0, "The user2s down bet should equal 0 Ether");

        (userUpBetForMarket, userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user3);
        assertEq(userUpBetForMarket, 1 ether, "The user3s up bet should equal 1 Ether");
        assertEq(userDownBetForMarket, 0, "The user3s down bet should equal 0 Ether");
    }

    function test_placeBet_multiUserUpAndDown() public 
    {
        _addSupportedAssets();

        MockERC20(MOCK_ASSET).mint(user1, 2 ether);
        MockERC20(MOCK_ASSET).mint(user2, 4 ether);
        MockERC20(MOCK_ASSET).mint(user3, 1 ether);

        int256 movementPercent = 2000; // 20%
        uint256 betExpiry = block.timestamp + 100 hours;

        uint256 marketId = betADay.addMarket(MOCK_SUPPORTED_ASSET_1, movementPercent, betExpiry);

        vm.prank(user1);
        MockERC20(MOCK_ASSET).approve(address(betADay), 2 ether);

        vm.prank(user2);
        MockERC20(MOCK_ASSET).approve(address(betADay), 4 ether);

        vm.prank(user3);
        MockERC20(MOCK_ASSET).approve(address(betADay), 1 ether);

        vm.prank(user1);
        betADay.placeBet(marketId, false, 2 ether);

        vm.prank(user2);
        betADay.placeBet(marketId, true, 4 ether);

        vm.prank(user3);
        betADay.placeBet(marketId, false, 1 ether);

        (int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout,
        int256 resolvedPrice) = betADay.getMarket(marketId);

        assertEq(createdPrice, 150000000000, "Created price should be at 150000000000");
        assertEq(createdAt, block.timestamp, "Created should be now");
        assertEq(resolvesAt, betExpiry, "Created should be now + 48h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_1, "Condition asset should be MOCK_SUPPORTED_ASSET_1");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 2000 (20%)");
        assertEq(upTotalBets, 4 ether, "There should be 4 ether in up bets");
        assertEq(downTotalBets, 3 ether, "There should be 3 ether down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
        assertEq(resolvedPrice, 0 ether, "Resolved price should be 0 ether");

        (int256 userUpBetForMarket, int256 userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user1);
        assertEq(userUpBetForMarket, 0 ether, "The user1s up bet should equal 0 Ether");
        assertEq(userDownBetForMarket, 2 ether, "The user1s down bet should equal 2 Ether");

        (userUpBetForMarket, userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user2);
        assertEq(userUpBetForMarket, 4 ether, "The user2s up bet should equal 4 Ether");
        assertEq(userDownBetForMarket, 0, "The user2s down bet should equal 0 Ether");

        (userUpBetForMarket, userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user3);
        assertEq(userUpBetForMarket, 0 ether, "The user3s up bet should equal 0 Ether");
        assertEq(userDownBetForMarket, 1 ether, "The user3s down bet should equal 1 Ether");
    }

    function test_placeBet_multiBetBeforeCutoff() public 
    {
        _addSupportedAssets();

        MockERC20(MOCK_ASSET).mint(user1, 2 ether);
        MockERC20(MOCK_ASSET).mint(user2, 4 ether);
        MockERC20(MOCK_ASSET).mint(user3, 1 ether);

        int256 movementPercent = 2000; // 20%
        uint256 betExpiry = block.timestamp + 100 hours;

        uint256 marketId = betADay.addMarket(MOCK_SUPPORTED_ASSET_1, movementPercent, betExpiry);

        vm.prank(user1);
        MockERC20(MOCK_ASSET).approve(address(betADay), 2 ether);

        vm.prank(user2);
        MockERC20(MOCK_ASSET).approve(address(betADay), 4 ether);

        vm.prank(user3);
        MockERC20(MOCK_ASSET).approve(address(betADay), 1 ether);

        vm.warp(50 hours);

        vm.prank(user1);
        betADay.placeBet(marketId, false, 2 ether);

        vm.warp(60 hours);

        vm.prank(user2);
        betADay.placeBet(marketId, true, 4 ether);

        vm.warp(75 hours);

        vm.prank(user3);
        betADay.placeBet(marketId, false, 1 ether);

        (int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout,
        int256 resolvedPrice) = betADay.getMarket(marketId);

        assertEq(createdPrice, 150000000000, "Created price should be at 150000000000");
        assertEq(createdAt, 1, "Created should be 1");
        assertEq(resolvesAt, betExpiry, "Created should be 1 + 48h");
        assertFalse(resolved, "Should not be resolved yet");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_1, "Condition asset should be MOCK_SUPPORTED_ASSET_1");
        assertEq(conditionPercent, movementPercent, "Movement percent should be 2000 (20%)");
        assertEq(upTotalBets, 4 ether, "There should be 4 ether in up bets");
        assertEq(downTotalBets, 3 ether, "There should be 3 ether down bets");
        assertFalse(upWins, "Up wins should not be set (defaults to false)");
        assertFalse(downWins, "Down wins should not be set (defaults to false)");
        assertEq(resolverPayout, 0, "Resolver should not have been paid");
        assertEq(housePayout, 0, "House should not have been paid");
        assertEq(resolvedPrice, 0 ether, "Resolved price should be 0 ether");

        (int256 userUpBetForMarket, int256 userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user1);
        assertEq(userUpBetForMarket, 0 ether, "The user1s up bet should equal 0 Ether");
        assertEq(userDownBetForMarket, 2 ether, "The user1s down bet should equal 2 Ether");

        (userUpBetForMarket, userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user2);
        assertEq(userUpBetForMarket, 4 ether, "The user2s up bet should equal 4 Ether");
        assertEq(userDownBetForMarket, 0, "The user2s down bet should equal 0 Ether");

        (userUpBetForMarket, userDownBetForMarket) = betADay.getUsersMarketBet(marketId, user3);
        assertEq(userUpBetForMarket, 0 ether, "The user3s up bet should equal 0 Ether");
        assertEq(userDownBetForMarket, 1 ether, "The user3s down bet should equal 1 Ether");
    }

    function test_placeBet_multiBetAfterCutoff() public 
    {
        _addSupportedAssets();

        MockERC20(MOCK_ASSET).mint(user1, 2 ether);
        MockERC20(MOCK_ASSET).mint(user2, 4 ether);
        MockERC20(MOCK_ASSET).mint(user3, 1 ether);

        int256 movementPercent = 2000; // 20%
        uint256 betExpiry = block.timestamp + 100 hours;

        uint256 marketId = betADay.addMarket(MOCK_SUPPORTED_ASSET_1, movementPercent, betExpiry);

        vm.prank(user1);
        MockERC20(MOCK_ASSET).approve(address(betADay), 2 ether);

        vm.prank(user2);
        MockERC20(MOCK_ASSET).approve(address(betADay), 4 ether);

        vm.prank(user3);
        MockERC20(MOCK_ASSET).approve(address(betADay), 1 ether);

        vm.warp(50 hours);

        vm.prank(user1);
        betADay.placeBet(marketId, false, 2 ether);

        vm.warp(60 hours);

        vm.prank(user2);
        betADay.placeBet(marketId, true, 4 ether);

        vm.warp(90 hours);

        vm.prank(user3);
        vm.expectRevert("Betting closed");
        betADay.placeBet(marketId, false, 1 ether);
    }

    function test_resolveMarket() public 
    {
        betADay.setHouseRakePercent(2000);

        _addSupportedAssets();

        uint256 marketId = _addMarket(MOCK_SUPPORTED_ASSET_1, 2000, 100 hours);

        _addBets(marketId);

        vm.warp(100 hours + 1);

        uint256 adminBalace = MockERC20(MOCK_ASSET).balanceOf(admin);
        uint256 houseBalace = MockERC20(MOCK_ASSET).balanceOf(houseRakeReceiver);

        assertEq(adminBalace, 0, "Admin balance should be 0");
        assertEq(houseBalace, 0, "House rake balance should be 0");

        MockOracle(MOCK_SUPPORTED_ASSET_ORACLE_1).setPrice(200000000000);

        vm.prank(admin);
        betADay.resolveMarket(marketId);

        adminBalace = MockERC20(MOCK_ASSET).balanceOf(admin);
        houseBalace = MockERC20(MOCK_ASSET).balanceOf(houseRakeReceiver);

        assertEq(adminBalace, (6 ether / 100) * 10, "Admin balance should be 6 ether / 10");
        assertEq(houseBalace, (6 ether / 100) * 20, "House rake balance should be 6 ether / 20");

        (int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address conditionAsset,
        int256 conditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout,
        int256 resolvedPrice) = betADay.getMarket(marketId);

        assertEq(createdPrice, 150000000000, "Created price should be at 150000000000");
        assertEq(resolvedPrice, 200000000000, "Resolved price should be at 200000000000");
        assertEq(createdAt, 1, "Created should be 1");
        assertTrue(resolved, "Should be resolved");
        assertGt(resolvesAt, 0, "Resolved at should be greater than 0");
        assertEq(conditionAsset, MOCK_SUPPORTED_ASSET_1, "Condition asset should be MOCK_SUPPORTED_ASSET_1");
        assertEq(conditionPercent, 2000, "Movement percent should be 2000 (20%)");
        assertEq(upTotalBets, 6 ether, "There should be 6 ether in up bets");
        assertEq(downTotalBets, 6 ether, "There should be 6 ether down bets");
        assertTrue(upWins, "Up wins should be true");
        assertFalse(downWins, "Down wins should be false");
        assertEq(resolverPayout, (6 ether / 100) * 10, "Resolver should have been paid (6 ether / 100) * 10");
        assertEq(housePayout, (6 ether / 100) * 20, "House should not have been paid (6 ether / 100) * 20");
        assertEq(resolvedPrice, 200000000000, "Resolved price should be 200000000000");
    }

    function _addMarket(address token, int256 movementPercent, uint256 timeToAdd) internal returns(uint256 marketId)
    {
        uint256 betExpiry = block.timestamp + timeToAdd;

        marketId = betADay.addMarket(token, movementPercent, betExpiry);
    }

    function _addBets(uint256 marketId) internal 
    {
        MockERC20(MOCK_ASSET).mint(user1, 2 ether);
        MockERC20(MOCK_ASSET).mint(user2, 4 ether);
        MockERC20(MOCK_ASSET).mint(user3, 6 ether);

        vm.prank(user1);
        MockERC20(MOCK_ASSET).approve(address(betADay), 2 ether);
        vm.prank(user2);
        MockERC20(MOCK_ASSET).approve(address(betADay), 4 ether);    
        vm.prank(user3);
        MockERC20(MOCK_ASSET).approve(address(betADay), 6 ether);

        vm.prank(user1);
        betADay.placeBet(marketId, false, 2 ether);      
        vm.prank(user2);
        betADay.placeBet(marketId, false, 4 ether);
        vm.prank(user3);
        betADay.placeBet(marketId, true, 6 ether);
    }

    function _addSupportedAssets() internal 
    {
        betADay.addConditionalSupportedAsset(MOCK_SUPPORTED_ASSET_1, MOCK_SUPPORTED_ASSET_ORACLE_1);
        betADay.addConditionalSupportedAsset(MOCK_SUPPORTED_ASSET_2, MOCK_SUPPORTED_ASSET_ORACLE_2);
    }
}
