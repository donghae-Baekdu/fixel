pragma solidity ^0.8.9;

import "./Position.sol";
import "./LpToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LpPool is LpToken {
    function addLiquidity(uint256 marginQty)
        public
        returns (uint256 lpTokenQty)
    {
        // TODO get price
        // TODO get fee tier of user
        // TODO check requirements; amount to transfer is less than balance
        // TODO mint amount of token
    }

    function removeLiquidity(uint256 lpTokenQty)
        public
        returns (uint256 marginQty)
    {
        // TODO get price
        // TODO check requirements; amount to transfer is less than balance
        // TODO burn amount of token
    }

    function getPrice() public view returns (uint256 _price) {
        // TODO supply: supply + unrealized pnl from position manager
        // TODO demand: USDC balance in this contract
    }
}
