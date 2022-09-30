pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAdmin} from "../../interfaces/IAdmin.sol";

contract USDC is ERC20 {
    address admin;

    uint8 public decimals = 6;

    constructor(address _admin) public ERC20("USD Token", "USD") {
        admin = _admin;
    }

    modifier checkAuthority() {
        require(
            msg.sender == IAdmin(admin).getPositionManager() ||
                msg.sender == IAdmin(admin).getLpPool(),
            "Sender doesn't have authority to mint"
        );
        _;
    }
/*
    function changeAdmin(address _newAdmin) public onlyOwner {
        //should this function exist?
    }
*/
    function mint(address account, uint amount) external checkAuthority {
        _mint(account, amount);
    }

    function burn(address account, uint amount) external checkAuthority {
        _burn(account,amount);
    }
}
