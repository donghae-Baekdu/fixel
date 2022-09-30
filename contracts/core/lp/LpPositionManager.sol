pragma solidity ^0.8.9;

import {LpPositionManagerStorage} from "./LpPositionManagerStorage.sol";
import {CommonStorage} from "../common/CommonStorage.sol";

import {IPriceOracle} from "../../interfaces/IPriceOracle.sol";
import {ITradePositionManager} from "../../interfaces/ITradePositionManager.sol";
import {IAdmin} from "../../interfaces/IAdmin.sol";
import {ILpPositionManager} from "../../interfaces/ILpPositionManager.sol";

import {MathUtil} from "../../libraries/MathUtil.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract LpPositionManager is
    Ownable,
    ILpPositionManager,
    LpPositionManagerStorage,
    CommonStorage
{
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

        ValueWithSign storage paidValue = userInfos[user].paidValue;

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

            uint256 notionalValue = MathUtil.mul(
                position.qty,
                price,
                POSITION_DECIMAL,
                PRICE_DECIMAL,
                VALUE_DECIMAL
            );

            uint256 collateralValue = getCollateralValue(user);

            checkMaxLeverageRequirement(user, notionalValue, collateralValue);

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
        Position storage position = positions[user];
        uint256 price = getLpPositionPrice();
        uint256 notionalValue = MathUtil.mul(
            position.qty,
            price,
            POSITION_DECIMAL,
            PRICE_DECIMAL,
            VALUE_DECIMAL
        );

        if (collateralId == 0) {
            ValueWithSign storage paidValue = userInfos[user].paidValue;
            (uint256 usdQty, bool usdIsPos) = MathUtil.add(
                notionalValue,
                paidValue.value,
                true,
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

        checkMaxLeverageRequirement(user, notionalValue, collateralValue);

        // transfer token
        if (collateralId == 0) {
            // TODO mint stable coin @oliver
        } else {
            address tokenAddress = collateralInfos[collateralId].tokenAddress;
            address vault = adminContract.getVault();
            IERC20(tokenAddress).transferFrom(vault, user, amount);
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
        address positionManager = adminContract.getTradePositionManager();
        (uint256 pnl, bool pnlIsPos) = ITradePositionManager(positionManager)
            .getPnl();
        (_value, ) = MathUtil.add(
            entryValue.value,
            pnl,
            entryValue.isPos,
            pnlIsPos
        );
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

    function checkMaxLeverageRequirement(
        address user,
        uint256 notionalValue,
        uint256 collateralValue
    ) internal view {
        ValueWithSign memory accountValue;
        ValueWithSign storage paidValue = userInfos[user].paidValue;
        (accountValue.value, accountValue.isPos) = MathUtil.add(
            notionalValue + collateralValue,
            paidValue.value,
            true,
            paidValue.isPos
        );

        require(
            accountValue.isPos &&
                accountValue.value * MAX_LEVERAGE > notionalValue &&
                accountValue.value >
                (notionalValue * INITIAL_MARGIN_FRACTION) / 10000,
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
