pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAdmin} from "../../interfaces/IAdmin.sol";

contract USD is ERC20 {
    address admin;
    address public underlyingAsset;

    uint8 _decimals = 6;

    constructor(address _admin, address _underlyingAsset)
        ERC20("USD Token", "USD")
    {
        admin = _admin;
        underlyingAsset = _underlyingAsset;
    }

    modifier checkAuthority() {
        require(
            msg.sender == IAdmin(admin).getTradePositionManager() ||
                msg.sender == IAdmin(admin).getLpPositionManager() || msg.sender == IAdmin(admin).getVault(),
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
    function mint(address account, uint amount) external checkAuthority {
        _mint(account, amount);
    }

    function burn(address account, uint amount) external checkAuthority {
        _burn(account, amount);
    }
}
