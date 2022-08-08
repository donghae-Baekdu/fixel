pragma solidity ^0.8.9;

import "./PositionController.sol";
import "./LpToken.sol";
import "./Factory.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IPositionController.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LpPool is LpToken, ILpPool {
    using SafeMath for uint256;
    using SafeMath for uint80;
    using SafeERC20 for IERC20;

    address owner;
    address factory;

    address public override underlyingToken;

    uint80 public constant feeTierDenom = 10000;
    uint80 public MINIMUM_UNDERLYING;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp

    constructor(address _owner, address _underlyingToken) public {
        owner = _owner;
        underlyingToken = _underlyingToken;
        factory = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not owner of this contract");
        _;
    }

    modifier onlyExchanger() {
        require(
            msg.sender == IFactory(factory).getPositionController(),
            "You are Exchanger of this pool"
        );
        _;
    }

    function addLiquidity(
        address user,
        uint256 depositQty,
        exchangerCall flag
    ) external returns (uint256 _lpTokenQty) {
        require(
            flag == exchangerCall.yes || flag == exchangerCall.no,
            "Improper flag"
        );

        if (flag == exchangerCall.yes) {
            require(
                msg.sender == IFactory(factory).getPositionController(),
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

        uint80 feeTier = flag == exchangerCall.yes
            ? defaultExchangeFeeTier
            : defaultLpFeeTier;

        // charge fee (send 30% to fee pot)
        uint256 amountToExchange = depositQty
            .mul(feeTierDenom.sub(feeTier))
            .div(feeTierDenom);
        // get lp token price

        uint256 totalFeeQty = depositQty.sub(amountToExchange);
        uint256 toFeePotQty = totalFeeQty.sub(
            totalFeeQty.mul(feeTierDenom.sub(feeTier)).div(feeTierDenom)
        );

        // transfer from user to lp pool
        IERC20(underlyingToken).safeTransferFrom(
            user,
            address(this),
            depositQty
        );
        // transfer from lp pool to fee pot
        IERC20(underlyingToken).safeTransferFrom(
            address(this),
            address(IFactory(factory).getFeePot()),
            toFeePotQty
        );

        // get number of token to mint
        uint256 collateralLocked = IERC20(underlyingToken).balanceOf(
            address(this)
        );
        uint256 potentialSupply = getPotentialSupply();
        // delta Collateral / Collateral locked * GD supply (decimals is GD's decimals)
        uint256 tokenToMint = amountToExchange.mul(potentialSupply).div(
            collateralLocked
        );

        // mint token
        _mint(msg.sender, tokenToMint);

        _lpTokenQty = tokenToMint;

        emit LiquidityAdded(user, depositQty, tokenToMint);
    }

    function removeLiquidity(
        address user,
        uint256 lpTokenQty,
        exchangerCall flag
    ) external returns (uint256 _withdrawQty) {
        require(
            flag == exchangerCall.yes || flag == exchangerCall.no,
            "Improper flag"
        );

        if (flag == exchangerCall.yes) {
            require(
                msg.sender == IFactory(factory).getPositionController(),
                "Not allowed to add liquidity as a trader"
            );
        }

        // amount to transfer is less than balance
        if (flag == exchangerCall.no) {
            require(
                IERC20(this).balanceOf(user) >= lpTokenQty,
                "Not Enough Balance To Withdraw"
            );
        }

        uint256 collateralLocked = IERC20(underlyingToken).balanceOf(
            address(this)
        );

        // get lp token price
        uint256 potentialSupply = getPotentialSupply();
        // delta GD / GD supply * Collateral locked (decimals is USDC's decimals)
        uint256 amountFromExchange = lpTokenQty.mul(collateralLocked).div(
            potentialSupply
        );

        uint80 feeTier = flag == exchangerCall.yes
            ? defaultExchangeFeeTier
            : defaultLpFeeTier;

        uint256 amountToWithdraw = amountFromExchange
            .mul(feeTierDenom.sub(feeTier))
            .div(feeTierDenom);

        uint256 totalFeeQty = amountFromExchange.sub(amountToWithdraw);
        uint256 toFeePotQty = totalFeeQty.sub(
            totalFeeQty.mul(feeTierDenom.sub(feeTier)).div(feeTierDenom)
        );

        // transfer from pool to user
        IERC20(underlyingToken).safeTransferFrom(
            address(this),
            user,
            amountToWithdraw
        );
        // transfer from lp pool to fee pot
        IERC20(underlyingToken).safeTransferFrom(
            address(this),
            address(IFactory(factory).getFeePot()),
            toFeePotQty
        );

        // burn lp token
        _burn(msg.sender, lpTokenQty);

        _withdrawQty = amountToWithdraw;

        emit LiquidityRemoved(user, amountToWithdraw, lpTokenQty);
    }

    function getPotentialSupply() public view returns (uint256 _qty) {
        // potential supply: supply + unrealized pnl from position manager
        address positionController = IFactory(factory).getPositionController();
        (bool isPositive, uint256 potentialSupply) = IPositionController(
            positionController
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
