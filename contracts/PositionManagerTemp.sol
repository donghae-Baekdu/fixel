pragma solidity ^0.8.9;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IPriceOracle} from "./interfaces/IPriceOracle.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {ILpPool} from "./interfaces/ILpPool.sol";
import {IPositionManagerTemp} from "./interfaces/IPositionManagerTemp.sol";
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

    uint8 public LEVERAGE_DECIMAL = 2;
    uint8 public FUNDING_RATE_DECIMAL = 4;
    uint8 public PRICE_DECIMAL = 9; // QTY_DECIMAL은 market info에
    uint8 public VALUE_DECIMAL = 18;

    uint8 public MAX_LEVERAGE = 20;

    address USDC_TOKEN_ADDRESS;

    IERC20 USDC;

    uint32 marketCount;

    mapping(uint32 => ValueWithSign) deltaFLPs;
    mapping(uint32 => ValueWithSign) notionalValueSum;

    //user -> marketId -> position
    mapping(address => mapping(uint32 => Position)) public positions;
    mapping(address => mapping(uint32 => Collateral)) public collaterals;
    mapping(address => UserInfo) public userInfos;
    mapping(address => mapping(uint32 => uint32)) public userPositionList;
    mapping(address => mapping(uint32 => uint32)) public userCollateralList;

    mapping(uint32 => MarketStatus) public marketStatus;
    mapping(uint32 => MarketInfo) public marketInfos;
    mapping(uint32 => CollateralInfo) public collateralInfos;

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
        ValueWithSign storage paidValue = userInfos[msg.sender].paidValue;

        uint256 notionalValue = MathWithSign.mul(
            qty,
            price,
            marketInfos[marketId].decimals,
            PRICE_DECIMAL,
            VALUE_DECIMAL
        );

        (paidValue.value, paidValue.isPos) = MathWithSign.add(
            paidValue.value,
            notionalValue,
            paidValue.isPos,
            !isLong
        );

        // TODO check if max leverage exceeded

        if (position.isOpened) {
            // TODO update qty
        } else {
            // TODO
        }
        // TODO update entry price

        // TODO update market status

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

        Position storage position = positions[msg.sender][marketId];

        // TODO open position. input unit is position qty. record notional value in GD value.
        // positions[msg.sender]
        ValueWithSign storage virtualBalance = userInfos[msg.sender].paidValue;
        if (position.isLong) {
            // TODO get delta of virtual balance considering decimals
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

    function getEssentialFactors(address user)
        public
        view
        returns (
            uint256 _notionalValue,
            uint256 _IM,
            uint256 _MM,
            ValueWithSign memory _willReceiveValue
        )
    {
        UserInfo storage userInfo = userInfos[user];
        uint32 positionCount = userInfo.positionCount;

        address priceOracle = factoryContract.getPriceOracle();

        for (uint32 i = 0; i < positionCount; i++) {
            uint32 marketId = userPositionList[user][i];
            Position storage position = positions[user][marketId];
            if (position.isOpened) {
                uint256 price = IPriceOracle(priceOracle).getPrice(marketId);
                MarketInfo storage marketInfo = marketInfos[marketId];
                uint256 notionalValue = MathWithSign.mul(
                    position.qty.value,
                    price,
                    marketInfo.decimals,
                    PRICE_DECIMAL,
                    VALUE_DECIMAL
                );
                _notionalValue += notionalValue;
                // add IM
                _IM +=
                    (notionalValue * marketInfo.initialMarginFraction) /
                    10000;
                // add MM
                _MM +=
                    (notionalValue * marketInfo.maintenanceMarginFraction) /
                    10000;
                // add will receive value
                (
                    _willReceiveValue.value,
                    _willReceiveValue.isPos
                ) = MathWithSign.add(
                    _willReceiveValue.value,
                    notionalValue,
                    _willReceiveValue.isPos,
                    position.isLong
                );
            }
        }
    }

    function getCollateralValue(address user)
        public
        view
        returns (uint256 _collateralValue)
    {
        // TODO get collateral value
        UserInfo storage userInfo = userInfos[user];
        uint32 collateralCount = userInfo.collateralCount;

        address priceOracle = factoryContract.getPriceOracle();

        for (uint32 i = 0; i < collateralCount; i++) {
            uint32 collateralId = userCollateralList[user][i];
            Collateral storage collateral = collaterals[user][collateralId];
            if (collateral.qty > 0) {
                uint256 price = IPriceOracle(priceOracle).getPrice(
                    collateralId
                );
                CollateralInfo storage collateralInfo = collateralInfos[
                    collateralId
                ];
                uint256 value = MathWithSign.mul(
                    collateral.qty,
                    price,
                    collateralInfo.decimals,
                    PRICE_DECIMAL,
                    VALUE_DECIMAL
                );
                _collateralValue += (value * collateralInfo.weight) / 10000;
            }
        }
    }
}
