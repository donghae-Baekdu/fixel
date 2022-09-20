pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {ILpPool} from "./interfaces/ILpPool.sol";
import "./interfaces/IPositionManagerTemp.sol";
import {MathWithSign} from "./libraries/MathWithSign.sol";
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
    mapping(address => UserInfo) public userInfos;

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
        Position storage position = positions[msg.sender][marketId];
        require(position.isLong == isLong, "Not opening the position");
        // TODO get price of asset
        address priceOracle = factoryContract.getPriceOracle();
        uint256 price = IPriceOracle(priceOracle).getPrice(marketId);

        // TODO open position. input unit is position qty. record notional value in GD value.
        // positions[msg.sender]
        ValueWithSign storage virtualBalance = userInfos[msg.sender]
            .virtualBalance;
        if (isLong) {
            // TODO get delta of virtual balance considering decimals
            // (virtualBalance.value, virtualBalance.isPos) = MathWithSign.sub(virtualBalance.value, virtualBalance.isPos, )
        } else {
            // TODO get delta of virtual balance considering decimals
            // (virtualBalance.value, virtualBalance.isPos) = MathWithSign.sub(virtualBalance.value, virtualBalance.isPos, )
        }

        // TODO check if max leverage exceeded

        if (position.isOpened) {
            // TODO update qty
        } else {
            // TODO
        }
        // TODO update entry price

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
        // TODO get price of asset
        address priceOracle = factoryContract.getPriceOracle();
        uint256 price = IPriceOracle(priceOracle).getPrice(marketId);

        // TODO open position. input unit is position qty. record notional value in GD value.
        // positions[msg.sender]
        ValueWithSign storage virtualBalance = userInfos[msg.sender]
            .virtualBalance;
        if (isLong) {
            // TODO get delta of virtual balance considering decimals
            // (virtualBalance.value, virtualBalance.isPos) = MathWithSign.sub(virtualBalance.value, virtualBalance.isPos, )
        } else {
            // TODO get delta of virtual balance considering decimals
            // (virtualBalance.value, virtualBalance.isPos) = MathWithSign.sub(virtualBalance.value, virtualBalance.isPos, )
        }

        // TODO check if max leverage exceeded

        // TODO update qty
        // TODO update entry price

        // TODO take fee from open notional value
    }

    function addCollateral(
        uint256 tokenId,
        uint256 liquidity,
        uint256 notionalValue // value as usdc
    ) external {
        // TODO add collateral
    }

    function removeCollateral(
        uint256 tokenId,
        uint256 margin,
        uint256 notionalValue
    ) external {
        // TODO withdraw liquidity
        // TODO check IM
    }

    function getAccountLeverage(address user) public view {
        // TODO get account leverage
    }

    function getUnrealizedProfit() external view {
        // TODO get net unrealized profit
    }

    function collectTradingFee(address user, uint256 tradeAmount)
        internal
        returns (uint256 fee)
    {
        fee = ILpPool(factoryContract.getLpPool()).collectExchangeFee(
            tradeAmount
        );
        // collaterals[user] = collaterals[user].sub(fee);
    }

    function liquidate(uint32 marketId, uint256 tokenId) external {}
}
