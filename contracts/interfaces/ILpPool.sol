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

    function addLiquidity(
        address user,
        uint256 depositQty,
        uint256 notionalValue,
        exchangerCall flag
    )
        external
        returns (uint256 _exchangedLpToken, uint256 _notionalValueInLpToken);

    function removeLiquidity(
        address user,
        uint256 lpTokenQty,
        uint256 notionalValue,
        exchangerCall flag
    ) external returns (uint256 _withdrawQty);

    function setFeeTier(uint80 fee, exchangerCall flag) external;

    function getFeeTier(exchangerCall flag)
        external
        view
        returns (uint80 _fee, uint80 _feeTierDenom);

    function getAmountToWithdraw(
        uint256 lpTokenQty, // LP token unit
        bool isExchangerCall
    )
        external
        view
        returns (uint256 _amountToWithdraw, uint256 _potentialSupply);

    function getAmountToMint(
        uint256 depositQty,
        uint256 notionalValue,
        bool isExchangerCall
    )
        external
        view
        returns (
            uint256 _amountToMint,
            uint256 _notionalValueInLpToken,
            uint256 _potentialSupply
        );

    function mint(address to, uint256 value) external;

    function burn(address to, uint256 value) external;

    function underlyingToken() external view returns (address);

    function collectExchangeFee(uint256 notionalValue)
        external
        returns (uint256 _totalFee);

    function collectLpFee(uint256 notionalValue)
        external
        returns (uint256 _totalFee);
}
