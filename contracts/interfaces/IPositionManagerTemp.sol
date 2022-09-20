pragma solidity ^0.8.9;

interface IPositionManagerTemp {
    struct ValueWithSign {
        uint256 value;
        bool isPos;
    }

    enum TradeType {
        OPEN,
        CLOSE
    }

    enum Status {
        OPEN,
        CLOSE
    }

    enum Sign {
        POS,
        NEG
    }

    struct UserInfo {
        uint256 collateral;
        ValueWithSign virtualBalance;
        uint32 positionCount;
    }

    struct Position {
        address user;
        uint32 marketId;
        ValueWithSign qty;
        uint256 entryPrice;
        uint256 lastOpenTimestamp;
        bool isLong;
        bool isOpened;
    }

    struct MarketStatus {
        ValueWithSign deltaFLP;
        ValueWithSign notionalValuePerPriceSum;
        uint256 totalLongNotionalValue;
        uint256 totalShortShortNotionalValue;
    }

    struct MarketInfo {
        string name;
        uint32 marketId;
        uint32 maxLeverage;
        uint32 liquidationThreshold;
        uint32 underlyingAssetId;
    }

    event ChangeMaxLeverage(uint32 marketId, uint32 maxLeverage);

    event AddMarket(string name, uint32 marketCount, uint32 maxLeverage);

    event OpenPosition(
        address user,
        uint32 marketId,
        uint32 leverage,
        bool isLong,
        uint256 margin,
        uint256 tokenId
    );

    event ClosePosition(
        address user,
        uint32 marketId,
        bool isLong,
        Sign pnlSign,
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
        uint256 qty,
        bool isLong
    ) external;

    function closePosition(uint32 marketId, uint256 amount)
        external
        returns (uint256);

    function addCollateral(
        uint256 tokenId,
        uint256 liquidity,
        uint256 notionalValue // value as usdc
    ) external;

    function removeCollateral(
        uint256 tokenId,
        uint256 margin,
        uint256 notionalValue
    ) external;

    function liquidate(uint32 marketId, uint256 tokenId) external;
}
