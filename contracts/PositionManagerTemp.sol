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
        address user,
        uint32 marketId,
        uint256 qty,
        bool isLong
    ) external {
        require(user == msg.sender, "No authority to order");
        // side check
        Position storage position = positions[user][marketId];
        UserInfo storage userInfo = userInfos[user];
        if (position.beenOpened) {
            require(position.isLong == isLong, "Not opening the position");
        } else {
            position.beenOpened = true;
            // push position
            userPositionList[user][userInfo.positionCount];
            userInfo.positionCount++;
        }
        // get price of asset
        address priceOracle = factoryContract.getPriceOracle();
        uint256 price = IPriceOracle(priceOracle).getPrice(marketId);

        // open position. input unit is position qty. record notional value in GD value.
        ValueWithSign storage paidValue = userInfo.paidValue;

        uint256 tradeNotionalValue = MathWithSign.mul(
            qty,
            price,
            marketInfos[marketId].decimals,
            PRICE_DECIMAL,
            VALUE_DECIMAL
        );

        (paidValue.value, paidValue.isPos) = MathWithSign.add(
            paidValue.value,
            tradeNotionalValue,
            paidValue.isPos,
            !isLong
        );

        position.entryPrice =
            (position.entryPrice * position.qty.value + price * qty) /
            (position.qty.value + qty);
        position.qty.value += qty;

        checkMaxLeverage(msg.sender);

        // update market status -> increase market's paid value
        MarketStatus storage market = marketStatus[marketId];
        ValueWithSign storage marketPaidValue = market.paidValue;

        (marketPaidValue.value, marketPaidValue.isPos) = MathWithSign.add(
            marketPaidValue.value,
            tradeNotionalValue,
            marketPaidValue.isPos,
            !isLong
        );

        if (isLong) {
            market.longQty += qty;
        } else {
            market.shortQty += qty;
        }

        // TODO take fee from open notional value
    }

    // process
    // 1. deltaGD - pnl
    // 2. collateral + pnl
    // no need side check
    function closePosition(
        address user,
        uint32 marketId,
        uint256 qty
    ) external {
        require(user == msg.sender, "No authority to order");
        // get price of asset
        address priceOracle = factoryContract.getPriceOracle();
        uint256 price = IPriceOracle(priceOracle).getPrice(marketId);

        Position storage position = positions[user][marketId];

        require(position.qty.value > qty, "Not enough amount to close");

        // TODO update paid value
        UserInfo storage userInfo = userInfos[user];
        ValueWithSign storage paidValue = userInfo.paidValue;

        uint256 tradeNotionalValue = MathWithSign.mul(
            qty,
            price,
            marketInfos[marketId].decimals,
            PRICE_DECIMAL,
            VALUE_DECIMAL
        );

        (paidValue.value, paidValue.isPos) = MathWithSign.add(
            paidValue.value,
            tradeNotionalValue,
            paidValue.isPos,
            position.isLong
        );

        // update qty
        position.qty.value -= qty;

        // TODO update market status
        MarketStatus storage market = marketStatus[marketId];
        ValueWithSign storage marketPaidValue = market.paidValue;

        (marketPaidValue.value, marketPaidValue.isPos) = MathWithSign.add(
            marketPaidValue.value,
            tradeNotionalValue,
            marketPaidValue.isPos,
            position.isLong
        );

        if (position.isLong) {
            market.longQty -= qty;
        } else {
            market.shortQty -= qty;
        }
    }

    function addCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external {
        // transfer token
        address tokenAddress = collateralInfos[collateralId].tokenAddress;
        address lpPool = factoryContract.getLpPool();
        IERC20(tokenAddress).transferFrom(user, lpPool, amount);

        Collateral storage collateral = collaterals[user][collateralId];
        // add to collateral list
        if (!collateral.beenDeposited) {
            UserInfo storage userInfo = userInfos[user];
            userCollateralList[user][userInfo.collateralCount] = collateralId;
            userInfo.collateralCount++;
            collateral.beenDeposited = true;
        }
        // add collateral
        collateral.qty += amount;
    }

    function removeCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external {
        Collateral storage collateral = collaterals[user][collateralId];
        require(collateral.qty >= amount, "Not enough token to withdraw");

        // reduce collateral
        collateral.qty -= amount;
        // check IM
        checkMaxLeverage(user);

        // TODO transfer token
        address tokenAddress = collateralInfos[collateralId].tokenAddress;
        address lpPool = factoryContract.getLpPool();
        IERC20(tokenAddress).transferFrom(lpPool, user, amount);
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

    function liquidate(uint32 marketId, uint256 tokenId) external {
        // TODO
    }

    function getLeverageFactors(address user)
        public
        view
        returns (
            uint256 _notionalValue,
            uint256 _IM,
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

    function getLiquidationFactors(address user)
        public
        view
        returns (uint256 _MM, ValueWithSign memory _willReceiveValue)
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

    function checkMaxLeverage(address user) internal view {
        (
            uint256 notionalValue,
            uint256 IM,
            ValueWithSign memory willReceiveValue
        ) = getLeverageFactors(user);

        uint256 collateralValue = getCollateralValue(user);

        ValueWithSign memory accountValue;
        ValueWithSign storage paidValue = userInfos[user].paidValue;
        (accountValue.value, accountValue.isPos) = MathWithSign.add(
            willReceiveValue.value,
            paidValue.value,
            willReceiveValue.isPos,
            paidValue.isPos
        );

        (accountValue.value, accountValue.isPos) = MathWithSign.add(
            collateralValue,
            accountValue.value,
            true,
            accountValue.isPos
        );

        require(
            accountValue.isPos &&
                accountValue.value * MAX_LEVERAGE > notionalValue &&
                accountValue.value > IM,
            "Exceeds Max Leverage"
        );
    }

    function collectTradingFee() internal {
        // TODO collect trading fee
    }
}
