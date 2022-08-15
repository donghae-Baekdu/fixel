pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IPositionController is IERC721Enumerable {
    enum TradeType {
        OPEN,
        CLOSE
    }

    enum Status {
        OPEN,
        CLOSE
    }

    enum Side {
        LONG,
        SHORT
    }

    enum Sign {
        POS,
        NEG
    }

    struct Position {
        uint32 marketId;
        uint32 leverage;
        uint256 margin;
        uint256 price;
        uint256 closePrice;
        uint256 initialAccFundingFee;
        uint256 openTimestamp;
        uint256 closeTimestamp;
        Sign initialFundingFeeSign;
        Side side;
        Status status;
    }

    struct MarketStatus {
        uint256 margin;
        Sign pnlSign;
        uint256 unrealizedPnl;
        uint256 totalLongPositionFactor;
        uint256 totalShortPositionFactor;
        uint256 lastPrice;
        uint256 lastBlockNumber;
    }

    struct MarketInfo {
        string name;
        uint32 maxLeverage;
        uint32 liquidationThreshold;
    }

    struct FundingFee {
        Sign sign;
        uint256 lastTimestamp;
        uint256 accRate; //bp
    }

    event ChangeMaxLeverage(uint32 marketId, uint32 _maxLeverage);

    event AddMarket( string name,uint32 marketCount, uint32 _maxLeverage);

    event OpenPosition(
        address user,
        uint32 marketId,
        uint32 leverage,
        Side side,
        uint256 margin,
        uint256 tokenId
    );

    event ClosePosition(
        address user,
        uint32 marketId,
        Side side,
        bool isProfit,
        uint256 tokenId,
        uint256 margin,
        uint256 pnl,
        uint256 receiveAmount
    );

    event Liquidation(
        address user,
        address liquidator,
        uint32 marketId,
        uint256 tokenId
    );

    function openPosition(
        uint32 marketId,
        uint32 leverage,
        uint256 liquidity,
        Side side
    ) external;

    function closePosition(uint32 marketId, uint256 tokenId) external returns(uint256);

    function liquidate(uint32 marketId, uint256 tokenId) external;
    
    function getMarketMaxLeverage(uint32 marketId)
        external
        view
        returns (uint32);

    function applyUnrealizedPnl(uint32 marketId)
        external
        returns (Sign, uint256);

    function getTotalUnrealizedPnl()
        external
        view
        returns (bool isPositive, uint256 value);

    function getUnrealizedPnl(uint32 marketId)
        external
        view
        returns (
            Sign isPositive,
            uint256 pnl,
            uint256 currentPrice
        );
        
    function getOwnedTokensIndex(address user, uint32 marketId) view external returns (uint256[] memory);

    function addMarket(
        string memory name,
        uint32 _maxLeverage,
        uint32 threshold
    ) external;
}
