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
    uint80 public constant toFeePotProportion = 3000;
    uint80 public MINIMUM_UNDERLYING;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp

    constructor(address _underlyingToken, address _factory) public {
        underlyingToken = _underlyingToken;
        factory = _factory;
    }

    modifier onlyExchanger() {
        require(
            msg.sender == IFactory(factory).getPositionManager(),
            "You are Exchanger of this pool"
        );
        _;
    }

    function addLiquidity(
        address user,
        uint256 depositQty,
        uint256 notionalValue, // unit is collateral
        exchangerCall flag
    ) external returns (uint256 _lpTokenQty) {
        require(
            flag == exchangerCall.yes || flag == exchangerCall.no,
            "Improper flag"
        );

        if (flag == exchangerCall.yes) {
            require(
                msg.sender == IFactory(factory).getPositionManager(),
                "Not allowed to add liquidity as a trader"
            );
        }

        if (flag == exchangerCall.no) {
            // amount to transfer is less than balance
            require(
                IERC20(underlyingToken).balanceOf(user) >= depositQty, // 이거 틀림
                "Not Enough Balance To Deposit"
            );
        }

        (uint256 amountToMint, uint256 totalFeeQty) = getAmountToMint(
            depositQty,
            notionalValue,
            flag
        );

        // transfer from user to lp pool
        IERC20(underlyingToken).safeTransferFrom(
            user,
            address(this),
            depositQty
        );

        uint256 toFeePotQty = totalFeeQty.sub(
            totalFeeQty.mul(feeTierDenom.sub(toFeePotProportion)).div(
                feeTierDenom
            )
        );

        // transfer from lp pool to fee pot
        IERC20(underlyingToken).transfer(
            address(IFactory(factory).getFeePot()),
            toFeePotQty
        );

        // mint token
        _mint(msg.sender, amountToMint);

        _lpTokenQty = amountToMint;

        emit LiquidityAdded(user, depositQty, amountToMint);
    }

    function getAmountToMint(
        uint256 depositQty,
        uint256 notionalValue,
        exchangerCall flag
    ) public view returns (uint256 _amountToMint, uint256 _totalFee) {
        uint80 feeTier = flag == exchangerCall.yes
            ? defaultExchangeFeeTier
            : defaultLpFeeTier;

        _totalFee = notionalValue.sub(
            notionalValue.mul(feeTierDenom.sub(feeTier)).div(feeTierDenom)
        );

        // charge fee (send 30% to fee pot)
        uint256 amountToExchange = depositQty.sub(_totalFee);

        uint256 potentialSupply = getPotentialSupply();
        uint256 collateralLocked = IERC20(underlyingToken).balanceOf(
            address(this)
        );

        // delta Collateral / Collateral locked * GD supply (decimals is GD's decimals)
        _amountToMint = (potentialSupply == 0 || collateralLocked == 0)
            ? amountToExchange.div(initialExachangeRate)
            : amountToExchange.mul(potentialSupply).div(collateralLocked);
    }

    function removeLiquidity(
        address user,
        uint256 lpTokenQty,
        uint256 notionalValue, // unit is lp token
        exchangerCall flag
    ) external returns (uint256 _withdrawQty) {
        require(
            flag == exchangerCall.yes || flag == exchangerCall.no,
            "Improper flag"
        );

        if (flag == exchangerCall.yes) {
            require(
                msg.sender == IFactory(factory).getPositionManager(),
                "Not allowed to remove liquidity as a trader"
            );
        }

        // amount to transfer is less than balance
        if (flag == exchangerCall.no) {
            require(
                IERC20(address(this)).balanceOf(user) >= lpTokenQty,
                "Not Enough Balance To Withdraw"
            );
        }

        (uint256 amountToWithdraw, uint256 totalFeeQty) = getAmountToWithdraw(
            lpTokenQty,
            notionalValue,
            flag
        );

        uint256 toFeePotQty = totalFeeQty.sub(
            totalFeeQty.mul(feeTierDenom.sub(toFeePotProportion)).div(
                feeTierDenom
            )
        );

        // transfer from pool to user
        IERC20(underlyingToken).transfer(user, amountToWithdraw);
        // transfer from lp pool to fee pot
        IERC20(underlyingToken).transfer(
            address(IFactory(factory).getFeePot()),
            toFeePotQty
        );
        // burn lp token
        _burn(msg.sender, lpTokenQty);

        _withdrawQty = amountToWithdraw;

        emit LiquidityRemoved(user, amountToWithdraw, lpTokenQty);
    }

    function getAmountToWithdraw(
        uint256 lpTokenQty,
        uint256 notionalValue,
        exchangerCall flag
    ) public view returns (uint256 _amountToWithdraw, uint256 _totalFee) {
        uint256 collateralLocked = IERC20(underlyingToken).balanceOf(
            address(this)
        );

        uint80 feeTier = flag == exchangerCall.yes
            ? defaultExchangeFeeTier
            : defaultLpFeeTier;

        // get lp token price
        uint256 potentialSupply = getPotentialSupply();
        // delta GD / GD supply * Collateral locked (decimals is USDC's decimals)
        uint256 lpFeeQty = notionalValue.sub(
            notionalValue.mul(feeTierDenom.sub(feeTier)).div(feeTierDenom)
        );
        uint256 amountFromExchange = lpTokenQty.mul(collateralLocked).div(
            potentialSupply
        );

        _totalFee = amountFromExchange.sub(
            amountFromExchange.mul(lpTokenQty.sub(lpFeeQty)).div(lpTokenQty)
        );

        _amountToWithdraw = amountFromExchange.sub(_totalFee);
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

    function setFeeTier(uint80 fee, exchangerCall flag) external onlyOwner {
        if (flag == exchangerCall.yes) {
            defaultExchangeFeeTier = fee;
        } else if (flag == exchangerCall.no) {
            defaultLpFeeTier = fee;
        }
    }

    function getFeeTier(exchangerCall flag)
        external
        view
        returns (uint80 _fee, uint80 _feeTierDenom)
    {
        _fee = flag == exchangerCall.yes
            ? defaultExchangeFeeTier
            : defaultLpFeeTier;
        _feeTierDenom = feeTierDenom;
    }

    function mint(address to, uint256 value) external onlyExchanger {
        _mint(to, value);
    }

    function burn(address to, uint256 value) external onlyExchanger {
        _burn(to, value);
    }
}
