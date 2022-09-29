pragma solidity ^0.8.9;

import {LpPoolStorage} from "./LpPoolStorage.sol";
import {CommonStorage} from "../common/CommonStorage.sol";

import {IPriceOracle} from "../../interfaces/IPriceOracle.sol";
import {IPositionManager} from "../../interfaces/IPositionManager.sol";
import {IAdmin} from "../../interfaces/IAdmin.sol";
import {ILpPool} from "../../interfaces/ILpPool.sol";

import {MathUtil} from "../../libraries/MathUtil.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract LpPool is Ownable, ILpPool, LpPoolStorage, CommonStorage {
    using SafeMath for uint256;

    constructor(address adminContract_) CommonStorage(adminContract_, 10, 25) {
        adminContract = IAdmin(adminContract_);
    }

    function buyPosition(address user, uint256 qty) external {
        require(user == msg.sender, "No authority to order");

        Position storage position = positions[user];

        updateStatusAfterTrade(user, position, qty, true);
    }

    function sellPosition(address user, uint256 qty) external {
        require(user == msg.sender, "No authority to order");

        Position storage position = positions[user];
        require(position.qty > qty, "Not enough qty to sell");

        updateStatusAfterTrade(user, position, qty, false);
    }

    function updateStatusAfterTrade(
        address user,
        Position storage position,
        uint256 qty,
        bool isBuy
    ) internal {
        // get LP Position price
        uint256 price = getLpPositionPrice();
        // get notional value
        uint256 paidValueDelta = MathUtil.mul(
            price,
            qty,
            PRICE_DECIMAL,
            POSITION_DECIMAL,
            VALUE_DECIMAL
        );
        uint256 fee = (paidValueDelta * getFeeTier(user)) / 10000;
        paidValueDelta = isBuy ? paidValueDelta + fee : paidValueDelta - fee;

        UserInfo storage userInfo = userInfos[user];
        ValueWithSign storage paidValue = userInfo.paidValue;

        (paidValue.value, paidValue.isPos) = MathUtil.add(
            paidValue.value,
            paidValueDelta,
            paidValue.isPos,
            !isBuy
        );

        if (isBuy) {
            position.entryPrice =
                (position.entryPrice * position.qty + price * qty) /
                (position.qty + qty);

            position.qty += qty;

            checkMaxLeverage(user);

            openInterest += qty;
        } else {
            position.qty -= qty;
            openInterest -= qty;
        }

        (entryValue.value, entryValue.isPos) = MathUtil.add(
            entryValue.value,
            paidValueDelta,
            entryValue.isPos,
            isBuy
        );
    }

    function addCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external {
        // transfer token
        if (collateralId == 0) {
            // TODO burn
        } else {
            address tokenAddress = collateralInfos[collateralId].tokenAddress;
            address lpPool = adminContract.getLpPool();
            IERC20(tokenAddress).transferFrom(user, lpPool, amount);
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
            // TODO mint stable coin
        } else {
            address tokenAddress = collateralInfos[collateralId].tokenAddress;
            address lpPool = adminContract.getLpPool();
            IERC20(tokenAddress).transferFrom(lpPool, user, amount);
        }
    }

    function getLpPositionPrice() public view returns (uint256 _price) {
        uint256 lpPoolValue = getLpPoolValue();
        _price = MathUtil.div(
            lpPoolValue,
            openInterest,
            VALUE_DECIMAL,
            0,
            PRICE_DECIMAL
        );
    }

    function getLpPoolValue() public view returns (uint256 _value) {
        address positionManager = adminContract.getPositionManager();
        (uint256 pnl, bool pnlIsPos) = IPositionManager(positionManager)
            .getPnl();
        (_value, ) = MathUtil.add(
            entryValue.value,
            pnl,
            entryValue.isPos,
            pnlIsPos
        );
    }

    function liquidate(
        address user,
        uint32 marketId,
        uint256 qty
    ) external {
        // TODO maximum 50% at once if exceeds certain qty
    }

    function addMarket() external {}

    function getLeverageFactors(address user)
        public
        view
        returns (
            uint256 _notionalValue,
            uint256 _IM,
            ValueWithSign memory _willReceiveValue
        )
    {}

    function getLiquidationFactors(address user)
        public
        view
        returns (uint256 _MM, ValueWithSign memory _willReceiveValue)
    {}

    function getCollateralValue(address user)
        public
        view
        returns (uint256 _collateralValue)
    {
        UserInfo storage userInfo = userInfos[user];
        uint32 collateralCount = userInfo.collateralCount;

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
}

// Note
// paid value 기록하는 방식은 알겠는데... 이미 position manager로부터 pnl을 받는 상황에서 별도 기록이 필요한가
// position manager이 손해보는 만큼 lp pool이 이득본거 아닌가 -> fee는 어떡할건데?
// ; price에는 position manager의 pnl이 반영되어 있으니깐...

// fee는 LP pool이 반영하고 있음
