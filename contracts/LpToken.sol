pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LpToken is IERC20 {
    using SafeMath for uint256;

    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    mapping(address => uint256) public nonces;

    function _mint(address to, uint256 value) internal {
        // TODO requiremnet - set admin contract
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        // TODO requiremnet - set admin contract
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
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

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) private {}

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {}
}
