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
    ValueWithSign paidValue;

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

        checkMaxLeverage(user);

        (paidValue.value, paidValue.isPos) = MathWithSign.add(
            paidValue.value,
            tradeNotionalValue,
            paidValue.isPos,
            !isLong
        );

        // update market status -> increase market's paid value
        MarketStatus storage market = marketStatus[marketId];
        if (isLong) {
            market.longQty += qty;
        } else {
            market.shortQty += qty;
        }

        // TODO take fee from open notional value
    }

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

        // update paid value
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

        (paidValue.value, paidValue.isPos) = MathWithSign.add(
            paidValue.value,
            tradeNotionalValue,
            paidValue.isPos,
            position.isLong
        );

        // update market status
        MarketStatus storage market = marketStatus[marketId];

        if (position.isLong) {
            market.longQty -= qty;
        } else {
            market.shortQty -= qty;
        }

        // TODO take fee from open notional value
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

        if (collateralId == 0) {
            ValueWithSign storage paidValue = userInfos[user].paidValue;
            (paidValue.value, paidValue.isPos) = MathWithSign.add(
                paidValue.value,
                amount,
                paidValue.isPos,
                true
            );
        } else {
            Collateral storage collateral = collaterals[user][collateralId];
            // add to collateral list
            if (!collateral.beenDeposited) {
                UserInfo storage userInfo = userInfos[user];
                userCollateralList[user][
                    userInfo.collateralCount
                ] = collateralId;
                userInfo.collateralCount++;
                collateral.beenDeposited = true;
            }
            // add collateral
            collateral.qty += amount;
        }
    }

    function removeCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external {
        (
            uint256 notionalValue,
            uint256 IM,
            ValueWithSign memory willReceiveValue
        ) = getLeverageFactors(user);

        if (collateralId == 0) {
            ValueWithSign storage paidValue = userInfos[user].paidValue;
            (uint256 usdQty, bool usdIsPos) = MathWithSign.add(
                willReceiveValue.value,
                paidValue.value,
                willReceiveValue.isPos,
                paidValue.isPos
            );

            require(
                usdIsPos == true && usdQty >= amount,
                "Not enough usd to withdraw"
            );

            (paidValue.value, paidValue.isPos) = MathWithSign.sub(
                paidValue.value,
                amount,
                paidValue.isPos,
                true
            );
        } else {
            Collateral storage collateral = collaterals[user][collateralId];
            require(collateral.qty >= amount, "Not enough token to withdraw");

            // reduce collateral
            collateral.qty -= amount;
        }
        uint256 collateralValue = getCollateralValue(user);

        checkMaxLeverageRequirement(
            user,
            notionalValue,
            IM,
            collateralValue,
            willReceiveValue
        );

        // transfer token
        address tokenAddress = collateralInfos[collateralId].tokenAddress;
        address lpPool = factoryContract.getLpPool();
        IERC20(tokenAddress).transferFrom(lpPool, user, amount);
    }

    function getPnl() external view returns (ValueWithSign memory _pnl) {
        address priceOracle = factoryContract.getPriceOracle();
        uint256[] memory prices = IPriceOracle(priceOracle).getPrices();
        (_pnl.value, _pnl.isPos) = (paidValue.value, paidValue.isPos);
        for (uint32 marketId = 0; marketId < marketCount; marketId++) {
            MarketStatus storage marketStatus = marketStatus[marketId];
            bool netIsLong = marketStatus.longQty >= marketStatus.shortQty;
            uint256 netPositionQty = netIsLong
                ? marketStatus.longQty - marketStatus.shortQty
                : marketStatus.shortQty - marketStatus.longQty;
            uint256 price = prices[marketId];
            MarketInfo storage marketInfo = marketInfos[marketId];
            uint256 notionalValue = MathWithSign.mul(
                netPositionQty,
                price,
                marketInfo.decimals,
                PRICE_DECIMAL,
                VALUE_DECIMAL
            );
            (_pnl.value, _pnl.isPos) = MathWithSign.add(
                _pnl.value,
                notionalValue,
                _pnl.isPos,
                netIsLong
            );
        }
    }

    function collectTradingFee(address user, uint256 tradeAmount)
        internal
        returns (uint256 _fee)
    {
        // TODO
    }

    function liquidate(
        address user,
        uint32 marketId,
        uint256 qty
    ) external {
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
        uint256[] memory prices = IPriceOracle(priceOracle).getPrices();

        for (uint32 i = 0; i < positionCount; i++) {
            uint32 marketId = userPositionList[user][i];
            Position storage position = positions[user][marketId];
            if (position.isOpened) {
                uint256 price = prices[marketId];
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
        uint256[] memory prices = IPriceOracle(priceOracle).getPrices();

        for (uint32 i = 0; i < positionCount; i++) {
            uint32 marketId = userPositionList[user][i];
            Position storage position = positions[user][marketId];
            if (position.isOpened) {
                uint256 price = prices[marketId];
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
        UserInfo storage userInfo = userInfos[user];
        uint32 collateralCount = userInfo.collateralCount;

        address priceOracle = factoryContract.getPriceOracle();
        uint256[] memory prices = IPriceOracle(priceOracle).getPrices();

        for (uint32 i = 0; i < collateralCount; i++) {
            uint32 collateralId = userCollateralList[user][i];
            Collateral storage collateral = collaterals[user][collateralId];
            if (collateral.qty > 0) {
                CollateralInfo storage collateralInfo = collateralInfos[
                    collateralId
                ];
                uint256 value = MathWithSign.mul(
                    collateral.qty,
                    prices[collateralId],
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

        checkMaxLeverageRequirement(
            user,
            notionalValue,
            IM,
            collateralValue,
            willReceiveValue
        );
    }

    function checkMaxLeverageRequirement(
        address user,
        uint256 notionalValue,
        uint256 IM,
        uint256 collateralValue,
        ValueWithSign memory willReceiveValue
    ) internal view {
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
}

// TODO
// fee 수취시 net pnl에 끼치는 영향
