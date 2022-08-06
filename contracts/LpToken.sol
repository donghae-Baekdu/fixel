pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LpToken is IERC20 {
    using SafeMath for uint;

    uint8 public constant decimals = 18;
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    mapping(address => uint) public nonces;

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
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function _transfer(
        address from,
        address to,
        uint value
    ) private {
        // TODO require needed
        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint value
    ) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        if (allowance[from][msg.sender] != type(uint128).max) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(
                amount
            );
        }
        _transfer(from, to, amount);
        return true;
    }
}
