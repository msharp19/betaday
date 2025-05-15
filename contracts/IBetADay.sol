// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBetADay{
    
    struct Market {
        int256 createdPrice;
        uint256 createdAt;
        uint256 resolvesAt;
        bool resolved;
        address resolvedBy;
        address conditionAsset;
        int256 upConditionPercent;
        uint256 upTotalBets;
        uint256 downTotalBets;
        bool upWins;
        bool downWins;
        uint256 resolverPayout;
        uint256 housePayout;
        mapping(address => int256) userBets;
    }

    struct SupportedAsset {
        bool isSupported;
        address oracleAddress;
    }

    struct AppStorage {
        address asset;
        uint256 nextMarketId;
        uint256 houseRakePercent; // Basis points (100 = 1%)
        address houseRakeReceiver;
        uint256 resolverPercent; // Basis points
        mapping(uint256 => Market) markets;
        mapping(address => SupportedAsset) supportedConditionalAssets;
    }

    event MarketAdded(uint256 indexed id, uint256 timestamp);
    event MarketResolved(uint256 indexed id, address indexed by, uint256 timestamp);
    event BetPlaced(uint256 indexed marketId, address indexed better, bool isUp, uint256 amount);
    event WinningsCollected(uint256 indexed marketId, address indexed winner, uint256 amount);
    event BetReturned(uint256 indexed marketId, address indexed who, uint256 amount);

    function addMarket(
        address _conditionAsset,
        int256 _upConditionPercent,
        int256 _downConditionPercent,
        uint256 _resolvesAt
    ) external returns(uint256 marketId);
    function resolveMarket(uint256 marketId) external;
    function placeBet(
        uint256 marketId,
        bool isUpBet,
        uint256 amount
    ) external returns(bool);
    function collectWinnings(uint256 marketId) external returns(uint256);
    function getAssetPrice(address asset) external view returns(int256);
    function getUsersMarketBet(uint256 marketId, address user) external view returns(int256 amount);
    function getMarket(uint256 marketId) external view returns(
        int256 createdPrice,
        uint256 createdAt,
        uint256 resolvesAt,
        bool resolved,
        address resolvedBy,
        address conditionAsset,
        int256 upConditionPercent,
        uint256 upTotalBets,
        uint256 downTotalBets,
        bool upWins,
        bool downWins,
        uint256 resolverPayout,
        uint256 housePayout
    );
    function isConditionalAssetSupported(address asset) external view returns(bool);
    function addConditionalSupportedAsset(address asset, address oracle) external;
}