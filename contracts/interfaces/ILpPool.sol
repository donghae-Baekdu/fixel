pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IFactory.sol";

interface ILpPool {
    enum exchangerCall {
        yes,
        no
    }

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
}
