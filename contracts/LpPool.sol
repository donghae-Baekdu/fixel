pragma solidity ^0.8.9;

import "./PositionController.sol";
import "./LpToken.sol";
import "./Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LpPool is LpToken {
    enum exchangerCall {
        yes,
        no
    }

    mapping(address => uint) public feeTier;
    address owner;
    address factory;
    address exchanger;

    constructor(address _owner) public {
        owner = _owner;
        factory = msg.sender;
    }

    function addLiquidity(
        address user,
        uint256 marginQty,
        exchangerCall flag
    ) public returns (uint256 lpTokenQty) {
        if (flag == exchangerCall.yes) {
            // require(msg.sender == )
        }
        // TODO get price
        uint256 lpTokenPrice = getPrice();
        // TODO get fee tier of user
        (uint80 feeTier, uint80 feeTierDenom) = Factory(factory).getFeeTier(
            user
        );
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
