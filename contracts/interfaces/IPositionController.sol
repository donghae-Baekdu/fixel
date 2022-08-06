pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

interface IPositionController is IERC721Enumerable {
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
        Side side;
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

    function openPosition(
        uint80 marketId,
        uint256 liquidity,
        uint32 leverage,
        Side side
    ) external;

    function getMarketMaxLeverage(uint80 marketId)
        external
        view
        returns (uint32);

    function applyUnrealizedPnl(uint80 marketId)
        external
        returns (Sign, uint256);

    function getUnrealizedPnl(uint80 marketId)
        external
        view
        returns (Sign isPositive, uint256 pnl);
}
