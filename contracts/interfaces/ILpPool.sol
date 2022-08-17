pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IFactory.sol";

interface ILpPool {
    enum exchangerCall {
        yes,
        no
    }

    event LiquidityAdded(
        address user,
        uint256 depositedCollateral,
        uint256 mintedLpToken,
        uint256 notionalValueInLpToken
    );

    event LiquidityRemoved(
        address user,
        uint256 withdrewCollateral,
        uint256 burntLpToken
    );

    struct Position {
        uint256 margin; // collateral unit
        uint256 notionalEntryAmount; // collateral unit
        uint256 lpPositionSize; // lp token unit
    }

    // debt = notionalEntryAmount - margin

    function addLiquidity(
        address user,
        uint256 depositQty, // unit is collateral
        uint256 notionalValue, // unit is collateral
        exchangerCall flag
    ) external returns (uint256 _amountToMint, uint256 _notionalValueInLpToken);

    function getAmountToMint(uint256 depositQty, uint256 notionalValue)
        external
        view
        returns (
            uint256 _amountToMint,
            uint256 _notionalValueInLpToken,
            uint256 _potentialSupply
        );

    function removeLiquidity(
        address user,
        uint256 liquidity, // lp token if exchanger, collateral if lp manager
        uint256 notionalValue, // unit is lp token
        exchangerCall flag
    ) external returns (uint256 _amountToWithdraw);

    function getAmountToWithdraw(
        uint256 lpTokenQty // LP token unit
    )
        external
        view
        returns (uint256 _amountToWithdraw, uint256 _potentialSupply);

    function getPotentialSupply() external view returns (uint256 _qty);

    function setFeeTier(uint80 fee, bool isExchangerCall) external;

    function getFeeTier(bool isExchangerCall)
        external
        view
        returns (uint80 _fee, uint80 _feeTierDenom);

    function mint(address to, uint256 value) external;

    function burn(address to, uint256 value) external;

    function collectExchangeFee(uint256 notionalValue)
        external
        returns (uint256 _totalFee);

    function collectLpFee(
        uint256 notionalValue // collateral unit
    ) external view returns (uint256 _totalFee);

    function collateralToLpTokenConvertUnit(
        uint256 potentialSupply,
        uint256 collateral
    ) external view returns (uint256 _lpToken);

    function lpTokenToCollateralConvertUnit(
        uint256 potentialSupply,
        uint256 lpToken
    ) external view returns (uint256 _collateral);

    function liquidate(address user) external;

    function underlyingToken() external view returns (address);
}
