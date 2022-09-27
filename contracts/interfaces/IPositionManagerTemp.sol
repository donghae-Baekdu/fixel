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
        ValueWithSign paidValue;
        uint32 positionCount;
        uint32 collateralCount;
    }

    struct Position {
        address user;
        uint32 marketId;
        ValueWithSign qty;
        uint256 entryPrice;
        uint256 lastOpenTimestamp;
        bool isLong;
        bool isOpened;
        bool beenOpened;
    }

    struct Collateral {
        address user;
        uint256 qty;
        uint32 collateralId;
        bool beenDeposited;
    }

    struct MarketStatus {
        ValueWithSign paidValue;
        uint256 longQty;
        uint256 shortQty;
    }

    struct MarketInfo {
        uint32 marketId;
        uint32 initialMarginFraction; // bp
        uint32 maintenanceMarginFraction; // bp
        uint8 decimals;
    }

    struct CollateralInfo {
        address tokenAddress;
        uint32 collateralId;
        uint32 weight;
        uint8 decimals;
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
        address user,
        uint32 marketId,
        uint256 qty,
        bool isLong
    ) external;

    function closePosition(
        address user,
        uint32 marketId,
        uint256 amount
    ) external;

    function addCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external;

    function removeCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external;

    function liquidate(uint32 marketId, uint256 tokenId) external;

    function getCollateralValue(address user)
        external
        view
        returns (uint256 _collateralValue);
}
