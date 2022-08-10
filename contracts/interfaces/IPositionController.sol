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
        uint80 marketId;
        uint32 leverage;
        uint256 margin;
        uint256 price;
        uint256 closePrice;
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

    event ChangeMaxLeverage(uint80 marketId, uint32 _maxLeverage);
    event AddMarket(uint80 marketCount, string name, uint32 _maxLeverage);

    event OpenPosition(
        address user,
        uint80 marketId,
        uint256 margin,
        uint32 leverage,
        Side side,
        uint256 tokenId
    );
    event ClosePosition(
        address user,
        uint80 marketId,
        uint256 margin,
        Side side,
        uint256 tokenId,
        bool isProfit,
        uint256 pnl,
        uint256 receiveAmount
    );

    event Liquidation(
        address user,
        address liquidator,
        uint80 marketId,
        uint256 tokenId
    );


    function openPosition(
        uint80 marketId,
        uint256 liquidity,
        uint32 leverage,
        Side side
    ) external;

    function closePosition(uint80 marketId, uint256 tokenId) external returns(uint256);

    function liquidate(uint80 marketId, uint256 tokenId) external;
    
    function getMarketMaxLeverage(uint80 marketId)
        external
        view
        returns (uint32);

    function applyUnrealizedPnl(uint80 marketId)
        external
        returns (Sign, uint256);

    function getTotalUnrealizedPnl()
        external
        view
        returns (bool isPositive, uint256 value);

    function getUnrealizedPnl(uint80 marketId)
        external
        view
        returns (
            Sign isPositive,
            uint256 pnl,
            uint256 currentPrice
        );
        
    function getOwnedTokensIndex(address user, uint80 marketId) view external returns (uint256[] memory);

    function addMarket(
        string memory name,
        uint32 _maxLeverage,
        uint256 threshold
    ) external;
}
