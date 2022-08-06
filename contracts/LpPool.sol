pragma solidity ^0.8.9;

import "./PositionController.sol";
import "./LpToken.sol";
import "./Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LpPool is LpToken {
    mapping(address => uint) public feeTier;
    address owner;
    address factory;
    address underlyingToken;

    constructor(address _owner, address _underlyingToken) public {
        owner = _owner;
        underlyingToken = _underlyingToken;
        factory = msg.sender;
    }

    function addLiquidity(
        address user,
        uint256 depositQty,
        IFactory.exchangerCall flag
    ) external returns (uint256 lpTokenQty) {
        uint80 feeTier;
        uint80 feeTierDenom;
        if (flag == IFactory.exchangerCall.yes) {
            require(
                msg.sender == Factory(factory).getPositionController(),
                "Not allowed to add liquidity as a trader"
            );
        }
        // amount to transfer is less than balance
        require(
            IERC20(underlyingToken).balanceOf(user) >= depositQty,
            "Not Enough Balance To Deposit"
        );

        // get lp token price
        uint256 lpTokenPrice = getPrice();
        // get fee tier of user
        (feeTier, feeTierDenom) = Factory(factory).getFeeTier(user, flag);
        // TODO charge fee and get number of token to mint

        // TODO mint amount of token
        _mint();
    }

    function removeLiquidity(
        address user,
        uint256 lpTokenQty,
        IFactory.exchangerCall flag
    ) external returns (uint256 withdrawQty) {
        uint80 feeTier;
        uint80 feeTierDenom;
        if (flag == IFactory.exchangerCall.yes) {
            require(
                msg.sender == Factory(factory).getPositionController(),
                "Not allowed to remove liquidity as a trader"
            );
        }

        // amount to transfer is less than balance
        require(
            IERC20(this).balanceOf(user) >= lpTokenQty,
            "Not Enough Balance To Withdraw"
        );

        // get lp token price
        uint256 lpTokenPrice = getPrice();
        // get fee tier of user
        (feeTier, feeTierDenom) = Factory(factory).getFeeTier(user, flag);
        // TODO get amount to burn and burn
        _burn();

        // TODO transfer to
    }

    function getPrice() public view returns (uint256 _price) {
        // TODO supply: supply + unrealized pnl from position manager
        // TODO demand: USDC balance in this contract
    }
}
