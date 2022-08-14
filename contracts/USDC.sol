pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract USDC is IERC20 {
    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    string public name = "USDC Example Code";
    string public symbol = "USDC-TEST";
    uint8 public decimals = 6;

    function transfer(address recipient, uint amount) external returns (bool) {
        balanceOf[msg.sender] = balanceOf[msg.sender] - amount;
        balanceOf[recipient] = balanceOf[recipient] + amount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool) {
        allowance[sender][msg.sender] = allowance[sender][msg.sender] - amount;
        balanceOf[sender] = balanceOf[sender] - amount;
        balanceOf[recipient] = balanceOf[recipient] + amount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function mint(address account, uint amount) external {
        balanceOf[account] = balanceOf[account] + amount;
        totalSupply = totalSupply + amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint amount) external {
        balanceOf[account] = balanceOf[account] + amount;
        totalSupply = totalSupply + amount;
        emit Transfer(account, address(0), amount);
    }
}
