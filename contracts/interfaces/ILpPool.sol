pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILpPool {
    function addLiquidity(uint256 marginQty)
        external
        returns (uint256 lpTokenQty);

    function removeLiquidity(uint256 lpTokenQty)
        external
        returns (uint256 marginQty);

    function mint(uint256 qty) external;

    function burn(uint256 qty) external;

    function getPrice(uint256 key) external view returns (uint256 _price);
}
