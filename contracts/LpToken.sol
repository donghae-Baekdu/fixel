pragma solidity ^0.8.9;

import "./Position.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LpToken is IERC20 {
    using SafeMath for uint;

    uint8 public constant decimals = 18;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    mapping(address => uint) public nonces;

    constructor() public {}

    function _mint() internal {
        // TODO requiremnet - set admin contract
        // TODO mint amount of token; refer synthetix kwenta
    }

    function _burn() internal {
        // TODO requiremnet - set admin contract
        // TODO burn amount of token; refer synthetix kwenta
    }

    function transfer(address to, uint256 amount)
        external
        override
        returns (bool)
    {}

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {}

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {}
}
