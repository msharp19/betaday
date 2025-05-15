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

contract BetADay is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, UUPSUpgradeable {
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

    bytes32 private constant AppStorageSlot = 0x078b9a5a10e60aff8f55e9477cc53791735a7ce2b851408e1eb5a144966fb300;

    event MarketAdded(uint256 indexed id, uint256 timestamp);
    event MarketResolved(uint256 indexed id, address indexed by, uint256 timestamp);
    event BetPlaced(uint256 indexed marketId, address indexed better, bool isUp, uint256 amount);
    event WinningsCollected(uint256 indexed marketId, address indexed winner, uint256 amount);
    event BetReturned(uint256 indexed marketId, address indexed who, uint256 amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _asset,
        uint256 _houseRakePercent,
        address _houseRakeReceiver,
        uint256 _resolverPercent
    ) public initializer {
        require(_asset != address(0), "Invalid asset");
        require(_houseRakeReceiver != address(0), "Invalid receiver");
        require(_houseRakePercent <= 1000, "House rake too high"); // Max 10%
        require(_resolverPercent <= 1000, "Resolver cut too high"); // Max 10%

        __ReentrancyGuard_init();
        __Ownable_init(_msgSender());
        __AccessControl_init();
        __UUPSUpgradeable_init();

        AppStorage storage $ = _appStorage();
        $.asset = _asset;
        $.houseRakePercent = _houseRakePercent;
        $.houseRakeReceiver = _houseRakeReceiver;
        $.resolverPercent = _resolverPercent;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function addMarket(
        address _conditionAsset,
        int256 _upConditionPercent,
        int256 _downConditionPercent,
        uint256 _resolvesAt
    ) external nonReentrant returns(uint256 marketId) {
        require(isConditionalAssetSupported(_conditionAsset), "Unsupported asset");
        require(_upConditionPercent >= 100, "Up condition too low"); // Minimum 1%
        require(_downConditionPercent >= 100, "Down condition too low");
        require(_resolvesAt > block.timestamp + 24 hours, "Resolution too soon");

        AppStorage storage $ = _appStorage();
        marketId = $.nextMarketId++;
        
        int256 price = getAssetPrice(_conditionAsset);
        
        Market storage market = $.markets[marketId];
        market.conditionAsset = _conditionAsset;
        market.createdPrice = price;
        market.createdAt = block.timestamp;
        market.resolvesAt = _resolvesAt;
        market.upConditionPercent = _upConditionPercent;

        emit MarketAdded(marketId, block.timestamp);
        return marketId;
    }

    function resolveMarket(uint256 marketId) external nonReentrant {
        AppStorage storage $ = _appStorage();
        Market storage market = $.markets[marketId];
        
        require(!market.resolved, "Already resolved");
        require(block.timestamp >= market.resolvesAt, "Too early to resolve");
        require(market.conditionAsset != address(0), "Invalid market");

        int256 currentPrice = getAssetPrice(market.conditionAsset);
        int256 percentMoved = _getPercentMoved(market.createdPrice, currentPrice);
        
        market.upWins = percentMoved > market.upConditionPercent;
        market.downWins = percentMoved < -market.upConditionPercent;
        if(market.upWins || market.downWins)
        {
            uint256 totalLosingBets = market.upWins ? market.downTotalBets : market.upTotalBets;     
            market.resolverPayout = _payoutResolver(totalLosingBets);
            market.housePayout = _payoutHouse(totalLosingBets);
        }

        market.resolved = true;
        market.resolvedBy = _msgSender();
        market.resolvesAt = block.timestamp;

        emit MarketResolved(marketId, _msgSender(), block.timestamp);
    }

    function placeBet(
        uint256 marketId,
        bool isUpBet,
        uint256 amount
    ) external nonReentrant returns(bool) {
        AppStorage storage $ = _appStorage();
        Market storage market = $.markets[marketId];
        
        require(market.conditionAsset != address(0), "Invalid market");
        require(block.timestamp < market.resolvesAt - 24 hours, "Betting closed");
        require(amount > 0, "Invalid bet amount");
        require(!market.resolved, "Market resolved");

        IERC20($.asset).transferFrom(_msgSender(), address(this), amount);
        
        if (isUpBet) {
            market.upTotalBets += amount;
            market.userBets[_msgSender()] += int256(amount);
        } else {
            market.downTotalBets += amount;
            market.userBets[_msgSender()] -= int256(amount);
        }

        emit BetPlaced(marketId, _msgSender(), isUpBet, amount);
        return true;
    }

    function collectWinnings(uint256 marketId) external nonReentrant returns(uint256) {
        AppStorage storage $ = _appStorage();
        Market storage market = $.markets[marketId];
        
        require(market.resolved, "Market not resolved");
        require(market.userBets[_msgSender()] != 0, "No bets placed");

        bool isUpWinner = market.upWins && market.userBets[_msgSender()] > 0;
        bool isDownWinner = market.downWins && market.userBets[_msgSender()] < 0;
        
        if(!isUpWinner && !isDownWinner)
        {
            // Return funds
            uint256 userBetToReturn = uint256(abs(market.userBets[_msgSender()]));
            market.userBets[_msgSender()] = 0;
            IERC20($.asset).transfer(_msgSender(), userBetToReturn);

            emit BetReturned(marketId, _msgSender(), userBetToReturn);

            return userBetToReturn;
        }

        uint256 totalWinnerBets = market.upWins ? market.upTotalBets : market.downTotalBets;
        uint256 totalLoserBets = market.upWins ? market.downTotalBets : market.upTotalBets;
        uint256 userBet = uint256(abs(market.userBets[_msgSender()]));
        
        uint256 netPot = totalLoserBets - market.resolverPayout - market.housePayout;
        uint256 amount = (userBet * netPot) / totalWinnerBets;
        
        market.userBets[_msgSender()] = 0;
        IERC20($.asset).transfer(_msgSender(), amount);

        emit WinningsCollected(marketId, _msgSender(), amount);
        
        return amount;
    }

    function getAssetPrice(address asset) public view returns(int256) {
        SupportedAsset memory supported = _appStorage().supportedConditionalAssets[asset];
        require(supported.isSupported, "Unsupported asset");
        
        AggregatorV3Interface oracle = AggregatorV3Interface(supported.oracleAddress);
        (, int256 price, , uint256 updatedAt, ) = oracle.latestRoundData();
        
        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt < 2 hours, "Stale price");
        return price;
    }

    function isConditionalAssetSupported(address asset) public view returns(bool) {
        return _appStorage().supportedConditionalAssets[asset].isSupported;
    }

    function addConditionalSupportedAsset(address asset, address oracle) external onlyOwner {
        require(asset != address(0), "Invalid asset");
        require(oracle != address(0), "Invalid oracle");
        _appStorage().supportedConditionalAssets[asset] = SupportedAsset(true, oracle);
    }

    function _payoutResolver(uint256 totalLosers) internal returns(uint256) {
        AppStorage storage $ = _appStorage();
        uint256 payout = (totalLosers * $.resolverPercent) / 10000;
        if (payout > 0) {
            IERC20($.asset).transfer(_msgSender(), payout);
        }
        return payout;
    }

    function _payoutHouse(uint256 totalLosers) internal returns(uint256) {
        AppStorage storage $ = _appStorage();
        uint256 payout = (totalLosers * $.houseRakePercent) / 10000;
        if (payout > 0) {
            IERC20($.asset).transfer($.houseRakeReceiver, payout);
        }
        return payout;
    }

    function _getPercentMoved(int256 original, int256 current) internal pure returns(int256) {
        require(original > 0, "Invalid original price");
        return ((current - original) * 10000) / original; // Basis points
    }

    function abs(int256 x) private pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    function _appStorage() private pure returns (AppStorage storage $) {
        assembly { $.slot := AppStorageSlot }
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}