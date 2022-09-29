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

    uint8 public POSITION_DECIMAL = 9;

    ValueWithSign entryValue;
    uint256 openInterest;

    mapping(address => UserInfo) public userInfos;

    mapping(address => Position) public positions;
}
