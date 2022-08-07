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
        uint256 mintedLpToken
    );

    event LiquidityRemoved(
        address user,
        uint256 withdrewCollateral,
        uint256 burntLpToken
    );

    function addLiquidity(
        address user,
        uint256 depositQty,
        exchangerCall flag
    ) external returns (uint256 lpTokenQty);

    function removeLiquidity(
        address user,
        uint256 lpTokenQty,
        exchangerCall flag
    ) external returns (uint256 withdrawQty);

    function setFeeTier(uint80 fee, exchangerCall flag) external;

    function getFeeTier(exchangerCall flag)
        external
        view
        returns (uint80 _fee, uint80 _feeTierDenom);

    function mint(address to, uint256 value) external;

    function burn(address to, uint256 value) external;
}
