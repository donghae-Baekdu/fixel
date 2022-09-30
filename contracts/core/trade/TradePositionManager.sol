pragma solidity ^0.8.9;

import {IPriceOracle} from "../../interfaces/IPriceOracle.sol";
import {IAdmin} from "../../interfaces/IAdmin.sol";
import {ILpPositionManager} from "../../interfaces/ILpPositionManager.sol";
import {ITradePositionManager} from "../../interfaces/ITradePositionManager.sol";
import {MathUtil} from "../../libraries/MathUtil.sol";

import {TradePositionManagerStorage} from "./TradePositionManagerStorage.sol";
import {CommonStorage} from "../common/CommonStorage.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract TradePositionManager is
    Ownable,
    ITradePositionManager,
    TradePositionManagerStorage,
    CommonStorage
{
    using SafeMath for uint256;

    constructor(address adminContract_) CommonStorage(adminContract_, 20, 10) {
        adminContract = IAdmin(adminContract_);
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

        updateStatusAfterTrade(user, position, marketId, qty, true);
    }

    function closePosition(
        address user,
        uint32 marketId,
        uint256 qty
    ) external {
        require(user == msg.sender, "No authority to order");

        Position storage position = positions[user][marketId];

        require(position.qty.value > qty, "Not enough amount to close");

        updateStatusAfterTrade(user, position, marketId, qty, false);
    }

    function updateStatusAfterTrade(
        address user,
        Position storage position,
        uint32 marketId,
        uint256 qty,
        bool isOpen
    ) internal {
        address priceOracle = adminContract.getPriceOracle();
        uint256 price = IPriceOracle(priceOracle).getPrice(marketId);

        ValueWithSign storage paidValue = userInfos[user].paidValue;

        uint256 paidValueDelta = MathUtil.mul(
            qty,
            price,
            markets[marketId].decimals,
            PRICE_DECIMAL,
            VALUE_DECIMAL
        );

        // take fee from open notional value
        uint256 fee = (paidValueDelta * getFeeTier(user)) / 10000;

        bool paidValueDeltaIsPos = isOpen ? !position.isLong : position.isLong;

        paidValueDelta = paidValueDeltaIsPos
            ? paidValueDelta - fee
            : paidValueDelta + fee;

        (paidValue.value, paidValue.isPos) = MathUtil.add(
            paidValue.value,
            paidValueDelta,
            paidValue.isPos,
            paidValueDeltaIsPos
        );

        // update qty
        if (isOpen) {
            position.entryPrice =
                (position.entryPrice * position.qty.value + price * qty) /
                (position.qty.value + qty);
            position.qty.value += qty;

            checkMaxLeverage(user);

            Market storage market = markets[marketId];

            if (position.isLong) {
                market.longQty += qty;
            } else {
                market.shortQty += qty;
            }
        } else {
            position.qty.value -= qty;

            Market storage market = markets[marketId];

            if (position.isLong) {
                market.longQty -= qty;
            } else {
                market.shortQty -= qty;
            }
        }

        (netPaidValue.value, netPaidValue.isPos) = MathUtil.add(
            netPaidValue.value,
            paidValueDelta,
            netPaidValue.isPos,
            paidValueDeltaIsPos
        );
    }

    function addCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external {
        // transfer token
        if (collateralId == 0) {
            // TODO burn @oliver
        } else {
            address tokenAddress = collateralInfos[collateralId].tokenAddress;
            address vault = adminContract.getVault();
            IERC20(tokenAddress).transferFrom(user, vault, amount);
        }

        if (collateralId == 0) {
            ValueWithSign storage paidValue = userInfos[user].paidValue;
            (paidValue.value, paidValue.isPos) = MathUtil.add(
                paidValue.value,
                MathUtil.convertDecimals(
                    amount,
                    collateralInfos[0].decimals,
                    VALUE_DECIMAL
                ),
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
            (uint256 usdQty, bool usdIsPos) = MathUtil.add(
                willReceiveValue.value,
                paidValue.value,
                willReceiveValue.isPos,
                paidValue.isPos
            );

            uint256 amountToValueUnit = MathUtil.convertDecimals(
                amount,
                collateralInfos[0].decimals,
                VALUE_DECIMAL
            );
            require(
                usdIsPos == true && usdQty >= amountToValueUnit,
                "Not enough usd to withdraw"
            );

            (paidValue.value, paidValue.isPos) = MathUtil.sub(
                paidValue.value,
                amountToValueUnit,
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
        if (collateralId == 0) {
            // TODO mint stable coin @oliver
        } else {
            address tokenAddress = collateralInfos[collateralId].tokenAddress;
            address vault = adminContract.getVault();
            IERC20(tokenAddress).transferFrom(vault, user, amount);
        }
    }

    function getPnl()
        external
        view
        returns (uint256 _pnlValue, bool _pnlIsPos)
    {
        address priceOracle = adminContract.getPriceOracle();
        uint256[] memory prices = IPriceOracle(priceOracle).getPrices();
        (_pnlValue, _pnlIsPos) = (netPaidValue.value, netPaidValue.isPos);
        for (uint32 i = 0; i < marketCount; i++) {
            uint32 marketId = marketList[i];
            Market storage market = markets[marketId];

            bool netIsLong = market.longQty >= market.shortQty;

            uint256 netPositionQty = netIsLong
                ? market.longQty - market.shortQty
                : market.shortQty - market.longQty;

            uint256 price = prices[marketId];

            uint256 notionalValue = MathUtil.mul(
                netPositionQty,
                price,
                market.decimals,
                PRICE_DECIMAL,
                VALUE_DECIMAL
            );
            (_pnlValue, _pnlIsPos) = MathUtil.add(
                _pnlValue,
                notionalValue,
                _pnlIsPos,
                netIsLong
            );
        }
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
        uint32 positionCount = userInfos[user].positionCount;

        address priceOracle = adminContract.getPriceOracle();
        uint256[] memory prices = IPriceOracle(priceOracle).getPrices();

        for (uint32 i = 0; i < positionCount; i++) {
            uint32 marketId = userPositionList[user][i];
            Position storage position = positions[user][marketId];
            if (position.isOpened) {
                uint256 price = prices[marketId];
                Market storage market = markets[marketId];
                uint256 notionalValue = MathUtil.mul(
                    position.qty.value,
                    price,
                    market.decimals,
                    PRICE_DECIMAL,
                    VALUE_DECIMAL
                );
                _notionalValue += notionalValue;
                // add IM
                _IM += (notionalValue * market.initialMarginFraction) / 10000;
                // add will receive value
                (_willReceiveValue.value, _willReceiveValue.isPos) = MathUtil
                    .add(
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
        uint32 positionCount = userInfos[user].positionCount;

        address priceOracle = adminContract.getPriceOracle();
        uint256[] memory prices = IPriceOracle(priceOracle).getPrices();

        for (uint32 i = 0; i < positionCount; i++) {
            uint32 marketId = userPositionList[user][i];
            Position storage position = positions[user][marketId];
            if (position.isOpened) {
                uint256 price = prices[marketId];
                Market storage market = markets[marketId];
                uint256 notionalValue = MathUtil.mul(
                    position.qty.value,
                    price,
                    market.decimals,
                    PRICE_DECIMAL,
                    VALUE_DECIMAL
                );
                // add MM
                _MM +=
                    (notionalValue * market.maintenanceMarginFraction) /
                    10000;
                // add will receive value
                (_willReceiveValue.value, _willReceiveValue.isPos) = MathUtil
                    .add(
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
        uint32 collateralCount = userInfos[user].collateralCount;

        address priceOracle = adminContract.getPriceOracle();
        uint256[] memory prices = IPriceOracle(priceOracle).getPrices();

        for (uint32 i = 0; i < collateralCount; i++) {
            uint32 collateralId = userCollateralList[user][i];
            Collateral storage collateral = collaterals[user][collateralId];
            if (collateral.qty > 0) {
                CollateralInfo storage collateralInfo = collateralInfos[
                    collateralId
                ];
                uint256 value = MathUtil.mul(
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
        (accountValue.value, accountValue.isPos) = MathUtil.add(
            willReceiveValue.value,
            paidValue.value,
            willReceiveValue.isPos,
            paidValue.isPos
        );

        (accountValue.value, accountValue.isPos) = MathUtil.add(
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

    function liquidate(
        address user,
        uint32 marketId,
        uint256 qty
    ) external {
        // TODO maximum 50% at once if exceeds certain qty
    }
}
