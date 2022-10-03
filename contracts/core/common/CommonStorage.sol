import {IAdmin} from "../../interfaces/IAdmin.sol";

contract CommonStorage {
    struct Collateral {
        address user;
        uint256 qty;
        uint32 collateralId;
        bool beenDeposited;
    }

    struct CollateralInfo {
        address tokenAddress;
        uint32 collateralId;
        uint32 oracleKey;
        uint32 weight;
        uint8 decimals;
    }

    uint8 public PRICE_DECIMAL = 9;
    uint8 public VALUE_DECIMAL = 18;
    uint8 public MAX_LEVERAGE;
    uint8 public DEFAULT_FEE_TIER; // bp
    uint32 public PROTOCOL_FEE_PROPORTION = 3000; //bp

    //user -> collateralId -> position
    mapping(address => mapping(uint32 => Collateral)) public collaterals;
    mapping(address => mapping(uint32 => uint32)) public userCollateralList;
    mapping(uint32 => CollateralInfo) public collateralInfos;

    mapping(address => uint8) feeTiers; // bp

    IAdmin adminContract;

    constructor(
        address adminContractAddress,
        uint8 MAX_LEVERAGE_,
        uint8 DEFAULT_FEE_TIER_
    ) {
        adminContract = IAdmin(adminContractAddress);
        MAX_LEVERAGE = MAX_LEVERAGE_;
        DEFAULT_FEE_TIER = DEFAULT_FEE_TIER_;
    }

    function setDefaultFeeTier(uint8 feeTier) external {
        // TODO only owner
        DEFAULT_FEE_TIER = feeTier;
    }

    function setProtoclFeeProportion(uint8 feeTier) external {
        // TODO only owner
        PROTOCOL_FEE_PROPORTION = feeTier;
    }

    function setFeeTier(address user, uint8 feeTier) external {
        // TODO only owner
        feeTiers[user] = feeTier;
    }

    function getFeeTier(address user) public view returns (uint8 _feeTier) {
        _feeTier = feeTiers[user] == 0 ? feeTiers[user] : DEFAULT_FEE_TIER;
    }

    function listNewCollateral(
        address tokenAddress,
        uint32 collateralId,
        uint32 oracleKey,
        uint32 weight,
        uint8 decimals
    ) external {
        // TODO only owner
        collateralInfos[collateralId] = CollateralInfo(
            tokenAddress,
            collateralId,
            oracleKey,
            weight,
            decimals
        );
    }
}
