pragma solidity ^0.8.9;

import "../position-manager/PositionManager.sol";
import "./LpToken.sol";
import "../../interfaces/IAdmin.sol";
import "../../interfaces/ILpPool.sol";
import "../../interfaces/IPositionManager.sol";
import "../../USDC.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";

contract LpPool is LpToken, ILpPool, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint80;
    using SafeERC20 for IERC20;

    address admin;

    address public override underlyingToken;
    uint8 public UNDERLYING_TOKEN_DECIMAL;

    uint80 public constant feeTierDenom = 10000;
    uint80 public constant initialExachangeRate = 1; // GD -> USD
    uint80 public MINIMUM_UNDERLYING;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp
    uint80 liquidationFee = 100;

    uint256 public override collateralLocked;
    mapping(address => Position) positions;

    constructor(address _underlyingToken, address _admin) public {
        underlyingToken = _underlyingToken;
        UNDERLYING_TOKEN_DECIMAL = USDC(underlyingToken).decimals();
        admin = _admin;
    }

    modifier onlyExchanger() {
        require(
            msg.sender == IAdmin(admin).getPositionManager(),
            "You are not Exchanger of this pool"
        );
        _;
    }

    function addLiquidity(
        address user,
        uint256 depositQty, // unit is collateral
        uint256 notionalValue, // unit is collateral
        exchangerCall flag
    )
        external
        returns (uint256 _amountToMint, uint256 _notionalValueInLpToken)
    {
        require(
            flag == exchangerCall.yes || flag == exchangerCall.no,
            "Improper flag"
        );

        bool isExchangerCall = flag == exchangerCall.yes;

        if (isExchangerCall) {
            require(
                msg.sender == IAdmin(admin).getPositionManager(),
                "Not allowed to add liquidity as a trader"
            );

            (_amountToMint, _notionalValueInLpToken) = getAmountToMint(
                depositQty,
                notionalValue
            );

            // transfer from user to lp pool
            IERC20(underlyingToken).safeTransferFrom(
                user,
                address(this),
                depositQty
            );

            collateralLocked += depositQty;

            // mint token
            if (_amountToMint != 0) {
                _mint(msg.sender, _amountToMint);
            }

            emit LiquidityAdded(
                user,
                depositQty,
                _amountToMint,
                _notionalValueInLpToken
            );
        } else {
            require(
                msg.sender == user,
                "Not allowed to remove liquidity as a lp"
            );

            require(
                IERC20(underlyingToken).balanceOf(user) >= depositQty,
                "Not Enough Balance To Deposit"
            );

            (_amountToMint, _notionalValueInLpToken) = getAmountToMint(
                notionalValue,
                notionalValue
            );

            // transfer from user to lp pool
            IERC20(underlyingToken).safeTransferFrom(
                user,
                address(this),
                depositQty
            );

            collateralLocked += notionalValue;
            positions[user].notionalEntryAmount += notionalValue;
            positions[user].margin += depositQty;

            _collectLpFee(user, notionalValue);

            // mint token
            if (_amountToMint != 0) {
                _mint(msg.sender, _amountToMint);
                positions[user].lpPositionSize += _amountToMint;
            }

            emit LiquidityAdded(
                user,
                depositQty,
                _amountToMint,
                _notionalValueInLpToken
            );
        }
    }

    function getAmountToMint(uint256 depositQty, uint256 notionalValue)
        public
        view
        returns (
            uint256 _amountToMint, // lp token unit
            uint256 _notionalValueInLpToken // lp token unit
        )
    {
        uint256 potentialSupply = getPotentialSupply();
        _amountToMint = collateralToLpTokenConvertUnit(
            potentialSupply,
            depositQty
        );

        _notionalValueInLpToken = collateralToLpTokenConvertUnit(
            potentialSupply,
            notionalValue
        );
    }

    function getInputAmountToMint(uint256 outputAmount)
        public
        view
        returns (uint256 _inputAmount)
    {
        uint256 potentialSupply = getPotentialSupply();
        _inputAmount = lpTokenToCollateralConvertUnit(
            potentialSupply,
            outputAmount
        );
    }

    function removeLiquidity(
        address user,
        uint256 liquidity, // lp token if exchanger, collateral if lp manager
        uint256 notionalValue, // unit is lp token
        exchangerCall flag
    ) public returns (uint256 _amountToWithdraw) {
        require(
            flag == exchangerCall.yes || flag == exchangerCall.no,
            "Improper flag"
        );

        bool isExchangerCall = flag == exchangerCall.yes;

        if (isExchangerCall) {
            require(
                msg.sender == IAdmin(admin).getPositionManager(),
                "Not allowed to remove liquidity as a trader"
            );

            (_amountToWithdraw, ) = getAmountToWithdraw(liquidity);

            // transfer from pool to user
            IERC20(underlyingToken).transfer(user, _amountToWithdraw);
            collateralLocked -= _amountToWithdraw;
            // burn lp token
            _burn(msg.sender, liquidity);

            emit LiquidityRemoved(user, _amountToWithdraw, liquidity);
        } else {
            require(
                msg.sender == user,
                "Not allowed to remove liquidity as a lp"
            );

            (
                uint256 exchangedAmount,
                uint256 potentialSupply
            ) = getAmountToWithdraw(notionalValue);

            Position storage position = positions[user];
            // collect fee
            uint256 totalFee = _collectLpFee(user, exchangedAmount);
            // burn lp token
            _burn(msg.sender, notionalValue);
            potentialSupply -= notionalValue;
            position.lpPositionSize -= notionalValue;

            // repay debt first
            _repayLpDebt(user, exchangedAmount);

            _amountToWithdraw = exchangedAmount.sub(totalFee);

            require(
                (
                    position
                        .margin
                        .add(
                            lpTokenToCollateralConvertUnit(
                                potentialSupply,
                                position.lpPositionSize
                            )
                        )
                        .sub(position.notionalEntryAmount)
                        .sub(liquidity)
                ).mul(1000).div(position.margin) >= 50,
                "Not able to remove liquidity. Too high leverage."
            );

            // transfer liquidity out if available
            IERC20(underlyingToken).transfer(user, liquidity);
            position.margin -= liquidity;

            emit LiquidityRemoved(user, _amountToWithdraw, liquidity);
        }
    }

    function getAmountToWithdraw(
        uint256 lpTokenQty // LP token unit
    )
        public
        view
        returns (uint256 _amountToWithdraw, uint256 _potentialSupply)
    {
        // get lp token price
        _potentialSupply = getPotentialSupply();

        _amountToWithdraw = lpTokenToCollateralConvertUnit(
            _potentialSupply,
            lpTokenQty
        );
    }

    function getPotentialSupply() public view returns (uint256 _qty) {
        // potential supply: supply + unrealized pnl from position manager
        address positionManager = IAdmin(admin).getPositionManager();
        (bool isPositive, uint256 potentialSupply) = IPositionManager(
            positionManager
        ).getTotalUnrealizedPnl();

        _qty = isPositive
            ? totalSupply.add(potentialSupply)
            : totalSupply.sub(potentialSupply);
    }

    function collectExchangeFee(uint256 notionalValue)
        external
        onlyExchanger
        returns (uint256 _totalFee)
    {
        _totalFee = notionalValue.sub(
            notionalValue.mul(feeTierDenom.sub(defaultExchangeFeeTier)).div(
                feeTierDenom
            )
        );
        _burn(msg.sender, _totalFee);
    }

    function _collectLpFee(
        address user,
        uint256 notionalValue // collateral unit
    ) internal returns (uint256 _totalFee) {
        _totalFee = getLpFee(notionalValue);
        positions[user].margin -= _totalFee;
    }

    function getLpFee(
        uint256 notionalValue // collateral unit
    ) public view returns (uint256 _totalFee) {
        _totalFee = notionalValue.sub(
            notionalValue.mul(feeTierDenom.sub(defaultLpFeeTier)).div(
                feeTierDenom
            )
        );
    }

    function _repayLpDebt(address user, uint256 repayAmount) internal {
        if (positions[user].notionalEntryAmount >= repayAmount) {
            positions[user].notionalEntryAmount -= repayAmount;
            collateralLocked -= repayAmount;
        } else {
            positions[user].margin += repayAmount;
            positions[user].margin -= positions[user].notionalEntryAmount;

            collateralLocked -= positions[user].notionalEntryAmount;

            positions[user].notionalEntryAmount = 0;
        }
    }

    function liquidate(
        address user,
        uint256 positionQty,
        address recipient
    ) external {
        (
            uint256 exchangedAmount,
            uint256 potentialSupply
        ) = getAmountToWithdraw(positionQty);
        Position storage position = positions[user];
        require(
            (
                position
                    .margin
                    .add(
                        lpTokenToCollateralConvertUnit(
                            potentialSupply,
                            position.lpPositionSize
                        )
                    )
                    .sub(position.notionalEntryAmount)
            ).mul(1000).div(position.margin) < 50,
            "Not able to liquidate"
        );
        // collect fee
        _collectLpFee(user, exchangedAmount);
        _receiveLiquidationFee(user, exchangedAmount, recipient);

        // burn lp token
        _burn(msg.sender, positionQty);
        potentialSupply -= positionQty;
        position.lpPositionSize -= positionQty;

        _repayLpDebt(user, exchangedAmount);
    }

    function _receiveLiquidationFee(
        address user,
        uint256 liquidationAmount, // collateral unit
        address recipient
    ) internal returns (uint256 _fee) {
        _fee = liquidationAmount.sub(
            liquidationAmount.mul(feeTierDenom.sub(liquidationFee)).div(
                feeTierDenom
            )
        );
        IERC20(underlyingToken).transfer(recipient, _fee);
        positions[user].margin -= _fee;
        collateralLocked -= _fee;
    }

    function collateralToLpTokenConvertUnit(
        uint256 potentialSupply,
        uint256 collateral
    ) public view returns (uint256 _lpToken) {
        // delta Collateral / Collateral locked * GD supply (decimals is GD's decimals)
        _lpToken = (potentialSupply == 0 || collateralLocked == 0)
            ? collateral
                .mul(uint(10)**decimals)
                .div(uint(10)**UNDERLYING_TOKEN_DECIMAL)
                .div(initialExachangeRate)
            : collateral.mul(potentialSupply).div(collateralLocked);
    }

    function lpTokenToCollateralConvertUnit(
        uint256 potentialSupply,
        uint256 lpToken
    ) public view returns (uint256 _collateral) {
        _collateral = (potentialSupply == 0 || collateralLocked == 0)
            ? lpToken
                .mul(uint(10)**UNDERLYING_TOKEN_DECIMAL)
                .mul(initialExachangeRate)
                .div(uint(10)**decimals)
            : lpToken.mul(collateralLocked).div(potentialSupply);
    }

    function mint(address to, uint256 value) external onlyExchanger {
        _mint(to, value);
    }

    function burn(address to, uint256 value) external onlyExchanger {
        _burn(to, value);
    }

    function setFeeTier(uint80 fee, bool isExchangerCall) external onlyOwner {
        if (isExchangerCall) {
            defaultExchangeFeeTier = fee;
        } else {
            defaultLpFeeTier = fee;
        }
    }

    function getFeeTier(bool isExchangerCall)
        external
        view
        returns (uint80 _fee, uint80 _feeTierDenom)
    {
        _fee = isExchangerCall ? defaultExchangeFeeTier : defaultLpFeeTier;
        _feeTierDenom = feeTierDenom;
    }

    function getLpPosition(address user)
        external
        view
        returns (
            uint256 _margin,
            uint256 _notionalEntryAmount,
            uint256 _lpPositionSize
        )
    {
        _margin = positions[user].margin;
        _notionalEntryAmount = positions[user].notionalEntryAmount;
        _lpPositionSize = positions[user].lpPositionSize;
    }

    function getLpPnl(address user) external view returns (uint256 _pnl) {
        uint256 potentialSupply = getPotentialSupply();
        _pnl = positions[user]
            .margin
            .add(
                lpTokenToCollateralConvertUnit(
                    potentialSupply,
                    positions[user].lpPositionSize
                )
            )
            .sub(positions[user].notionalEntryAmount);
    }
}
