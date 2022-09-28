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
        uint256 qty;
        uint256 entryPrice;
        uint256 lastOpenTimestamp;
        bool isLong;
        bool isOpened;
        bool beenOpened;
    }

    ValueWithSign netPaidValue;

    mapping(address => UserInfo) public userInfos;

    mapping(address => Position) public positions;
}
