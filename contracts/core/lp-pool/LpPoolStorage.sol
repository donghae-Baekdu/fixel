import {IAdmin} from "../../interfaces/IAdmin.sol";

contract LpPoolStorage {
    struct ValueWithSign {
        uint256 value;
        bool isPos;
    }

    struct UserInfo {
        ValueWithSign paidValue;
        uint32 collateralCount;
    }

    struct Position {
        address user;
        uint256 qty;
        uint256 entryPrice;
        uint256 lastOpenTimestamp;
    }

    ValueWithSign entryValue;
    uint256 openInterest;

    uint8 public POSITION_DECIMAL = 9;
    uint32 public INITIAL_MARGIN_FRACTION = 500; // bp
    uint32 public MAINT_MARGIN_FRACTION = 200; // bp

    mapping(address => UserInfo) public userInfos;

    mapping(address => Position) public positions;

    function setInitialMarginFraction(uint32 IR) external {
        // TODO only owner
        INITIAL_MARGIN_FRACTION = IR;
    }

    function setMaintMarginFraction(uint32 MMR) external {
        // TODO only owner
        MAINT_MARGIN_FRACTION = MMR;
    }
}
