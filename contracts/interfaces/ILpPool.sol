pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IFactory.sol";

interface ILpPool {
    function addLiquidity(
        address user,
        uint256 depositQty,
        IFactory.exchangerCall flag
    ) external returns (uint256 lpTokenQty);

    function removeLiquidity(
        address user,
        uint256 lpTokenQty,
        IFactory.exchangerCall flag
    ) external returns (uint256 withdrawQty);

    function mint(uint256 qty) external;

    function burn(uint256 qty) external;

    function getPrice(uint256 key) external view returns (uint256 _price);
}
