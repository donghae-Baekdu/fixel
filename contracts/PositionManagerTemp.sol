pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IPositionManagerTemp.sol";
import "hardhat/console.sol";

//TODO: calculate funding fee -> complete
//TODO: apply funding fee when close position -> complete
//TODO: apply funding fee to liquidation condition -> complete

//TODO: change margin structure -> complete
//TODO: add modify position
//TODO: add sign to currentMargin, consider negative balance
contract PositionManagerTemp is Ownable, IPositionManagerTemp {
    using SafeMath for uint256;

    uint256 public LEVERAGE_DECIMAL = 2;
    uint256 public FUNDING_RATE_DECIMAL = 4;

    address USDC_TOKEN_ADDRESS;

    IERC20 USDC;

    uint32 marketCount;

    mapping(uint32 => ValueWithSign) deltaFLPs;
    mapping(uint32 => ValueWithSign) notionalValueSum;

    //user -> marketId -> position
    mapping(address => mapping(uint32 => Position)) public positions;
    mapping(address => uint256) public collaterals;

    mapping(uint32 => MarketStatus) public marketStatus;
    mapping(uint32 => MarketInfo) public marketInfo;

    IFactory factoryContract;

    constructor(address factoryContract_, address usdc_) {
        factoryContract = IFactory(factoryContract_);
        USDC = IERC20(usdc_);
    }

    function openPosition(
        uint32 marketId,
        uint256 qty,
        bool isLong
    ) external {
        // side check
        require(
            positions[msg.sender][marketId].isLong == isLong,
            "Not opening the position"
        );
        // TODO open position. input unit is position qty. record notional value in GD value.

        // TODO update average price

        // TODO take fee from open notional value
    }

    // process
    // 1. deltaGD - pnl
    // 2. collateral + pnl
    // no need side check
    function closePosition(uint32 marketId, uint256 amount)
        external
        returns (uint256)
    {
        // TODO take fee
        // TODO close position. input unit is position qty. reduce notional value in GD value.
        // TODO update position
    }

    function addCollateral(
        uint256 tokenId,
        uint256 liquidity,
        uint256 notionalValue // value as usdc
    ) external {
        // TODO pay USDC and add GD token as collateral
    }

    function removeCollateral(
        uint256 tokenId,
        uint256 margin,
        uint256 notionalValue
    ) external {
        // TODO burn GD token and withdraw USDC
    }

    function collectTradingFee(address user, uint256 tradeAmount)
        internal
        returns (uint256 fee)
    {
        fee = ILpPool(factoryContract.getLpPool()).collectExchangeFee(
            tradeAmount
        );
        collaterals[user] = collaterals[user].sub(fee);
    }

    function liquidate(uint32 marketId, uint256 tokenId) external {}
}
