pragma solidity ^0.8.9;

import "./PositionManager.sol";
import "./LpToken.sol";
import "./Factory.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IPositionManager.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";

contract LpPool is LpToken, ILpPool, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint80;
    using SafeERC20 for IERC20;

    address factory;

    address public override underlyingToken;

    uint80 public constant feeTierDenom = 10000;
    uint80 public constant initialExachangeRate = 1; // GD -> USD
    uint80 public MINIMUM_UNDERLYING;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp

    uint256 collateralLocked;
    mapping(address => Position) positions;

    constructor(address _underlyingToken, address _factory) public {
        underlyingToken = _underlyingToken;
        factory = _factory;
    }

    modifier onlyExchanger() {
        require(
            msg.sender == IFactory(factory).getPositionManager(),
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
                msg.sender == IFactory(factory).getPositionManager(),
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
                IERC20(underlyingToken).balanceOf(user) >= depositQty,
                "Not Enough Balance To Deposit"
            );

            uint256 totalFee = collectLpFee(notionalValue);

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
            positions[user].margin -= totalFee;

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
                msg.sender == IFactory(factory).getPositionManager(),
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
                msg.sender == address(this),
                "Not allowed to remove liquidity as a lp"
            );

            uint256 potentialSupply;
            (_amountToWithdraw, potentialSupply) = getAmountToWithdraw(
                notionalValue
            );

            // collect fee
            uint256 totalFee = collectLpFee(_amountToWithdraw);
            _amountToWithdraw -= totalFee;
            // burn lp token
            _burn(msg.sender, notionalValue);
            potentialSupply -= notionalValue;
            positions[user].lpPositionSize -= notionalValue;
            if (positions[user].notionalEntryAmount >= _amountToWithdraw) {
                positions[user].notionalEntryAmount -= _amountToWithdraw;
            } else {
                positions[user].margin += _amountToWithdraw;
                positions[user].margin -= positions[user].notionalEntryAmount;

                positions[user].notionalEntryAmount = 0;
            }
            collateralLocked -= _amountToWithdraw;

            require(
                (
                    positions[user]
                        .margin
                        .add(
                            lpTokenToCollateralConvertUnit(
                                potentialSupply,
                                positions[user].lpPositionSize
                            )
                        )
                        .sub(positions[user].notionalEntryAmount)
                        .sub(liquidity)
                ).mul(100).div(positions[user].margin) >= 1,
                "Not able to remove liquidity. Too high leverage."
            );

            // transfer liquidity out if available
            IERC20(underlyingToken).transfer(user, liquidity);
            collateralLocked -= liquidity;

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
        address positionManager = IFactory(factory).getPositionManager();
        (bool isPositive, uint256 potentialSupply) = IPositionManager(
            positionManager
        ).getTotalUnrealizedPnl();

        _qty = isPositive
            ? totalSupply.add(potentialSupply)
            : totalSupply.sub(potentialSupply);
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

    function mint(address to, uint256 value) external onlyExchanger {
        _mint(to, value);
    }

    function burn(address to, uint256 value) external onlyExchanger {
        _burn(to, value);
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

    function collectLpFee(
        uint256 notionalValue // collateral unit
    ) public view returns (uint256 _totalFee) {
        _totalFee = notionalValue.sub(
            notionalValue.mul(feeTierDenom.sub(defaultLpFeeTier)).div(
                feeTierDenom
            )
        );
    }

    function collateralToLpTokenConvertUnit(
        uint256 potentialSupply,
        uint256 collateral
    ) public view returns (uint256 _lpToken) {
        // delta Collateral / Collateral locked * GD supply (decimals is GD's decimals)
        _lpToken = (potentialSupply == 0 || collateralLocked == 0)
            ? collateral.div(initialExachangeRate)
            : collateral.mul(potentialSupply).div(collateralLocked);
    }

    function lpTokenToCollateralConvertUnit(
        uint256 potentialSupply,
        uint256 lpToken
    ) public view returns (uint256 _collateral) {
        _collateral = lpToken.mul(collateralLocked).div(potentialSupply);
    }

    function liquidate(address user) external {
        uint256 potentialSupply = getPotentialSupply();
        require(
            (
                positions[user]
                    .margin
                    .add(
                        lpTokenToCollateralConvertUnit(
                            potentialSupply,
                            positions[user].lpPositionSize
                        )
                    )
                    .sub(positions[user].notionalEntryAmount)
            ).mul(100).div(positions[user].margin) < 1,
            "Not able to remove liquidity. Too high leverage."
        );
        // TODO liquidate
    }
}
