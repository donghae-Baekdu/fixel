import {IAdmin} from "../../interfaces/IAdmin.sol";

contract LpPoolStorage {
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

    struct Collateral {
        address user;
        uint256 qty;
        uint32 collateralId;
        bool beenDeposited;
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

    struct CollateralInfo {
        address tokenAddress;
        uint32 collateralId;
        uint32 weight;
        uint8 decimals;
    }

    uint8 public LEVERAGE_DECIMAL = 2;
    uint8 public FUNDING_RATE_DECIMAL = 4;
    uint8 public PRICE_DECIMAL = 9; // QTY_DECIMAL은 market info에
    uint8 public VALUE_DECIMAL = 18;
    uint8 public MAX_LEVERAGE = 20;

    uint32 marketCount;
    ValueWithSign netPaidValue;

    mapping(address => UserInfo) public userInfos;

    mapping(address => Position) public positions;

    //user -> collateralId -> position
    mapping(address => mapping(uint32 => Collateral)) public collaterals;
    mapping(address => mapping(uint32 => uint32)) public userCollateralList;

    mapping(uint32 => MarketStatus) public marketStatus;
    mapping(uint32 => MarketInfo) public marketInfos;
    mapping(uint32 => CollateralInfo) public collateralInfos;

    mapping(address => uint8) feeTier; // bp

    IAdmin adminContract;
}
