pragma solidity ^0.8.9;

//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUSD} from "../../interfaces/IUSD.sol";
import {IAdmin} from "../../interfaces/IAdmin.sol";

contract USD is IUSD {
    address admin;

    uint public totalSupply;
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;
    string public name = "USD Token";
    string public symbol = "USD";

    uint8 _decimals = 6;

    constructor(address admin_) {
        admin = admin_;
    }

    modifier checkAuthority() {
        require(
            msg.sender == IAdmin(admin).getTradePositionManager() ||
                msg.sender == IAdmin(admin).getLpPositionManager() ||
                msg.sender == IAdmin(admin).getVault(),
            "Sender doesn't have authority to mint"
        );
        _;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /*
    function changeAdmin(address _newAdmin) public onlyOwner {
        //should this function exist?
    }
*/

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

    function mint(address account, uint amount) external checkAuthority {
        balanceOf[account] = balanceOf[account] + amount;
        totalSupply = totalSupply + amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint amount) external checkAuthority {
        balanceOf[account] = balanceOf[account] - amount;
        totalSupply = totalSupply - amount;
        emit Transfer(account, address(0), amount);
    }
}
