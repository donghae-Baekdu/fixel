import {IAdmin} from "../../interfaces/IAdmin.sol";

contract PositionManagerStorage {
    struct ValueWithSign {
        uint256 value;
        bool isPos;
    }

    struct UserInfo {
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

    struct Market {
        uint256 longQty;
        uint256 shortQty;
        uint32 marketId;
        uint32 oracleId;
        uint32 initialMarginFraction; // bp
        uint32 maintenanceMarginFraction; // bp
        uint8 decimals;
    }

    uint8 public FUNDING_RATE_DECIMAL = 4;

    ValueWithSign netPaidValue;

    mapping(address => UserInfo) public userInfos;

    //user -> marketId -> position
    mapping(address => mapping(uint32 => Position)) public positions;
    mapping(address => mapping(uint32 => uint32)) public userPositionList;

    mapping(uint32 => Market) public markets;

    uint32 marketCount;
    mapping(uint32 => uint32) public marketList;

    function listNewMarket(
        uint32 marketId,
        uint32 oracleId,
        uint32 initialMarginFraction,
        uint32 maintenanceMarginFraction,
        uint8 decimals
    ) external {
        // TODO only owner
        markets[marketId] = Market(
            0,
            0,
            marketId,
            oracleId,
            initialMarginFraction,
            maintenanceMarginFraction,
            decimals
        );
        marketList[marketCount] = marketId;
        marketCount++;
    }
}
