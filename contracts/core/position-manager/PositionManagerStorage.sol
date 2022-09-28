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

    struct MarketStatus {
        uint256 longQty;
        uint256 shortQty;
    }

    struct MarketInfo {
        uint32 marketId;
        uint32 initialMarginFraction; // bp
        uint32 maintenanceMarginFraction; // bp
        uint8 decimals;
    }

    uint8 public LEVERAGE_DECIMAL = 2;
    uint8 public FUNDING_RATE_DECIMAL = 4;

    uint32 marketCount;
    ValueWithSign netPaidValue;

    mapping(address => UserInfo) public userInfos;

    //user -> marketId -> position
    mapping(address => mapping(uint32 => Position)) public positions;
    mapping(address => mapping(uint32 => uint32)) public userPositionList;

    mapping(uint32 => MarketStatus) public marketStatus;
    mapping(uint32 => MarketInfo) public marketInfos;
}
