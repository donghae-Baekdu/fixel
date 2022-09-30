pragma solidity ^0.8.9;

import {IAdmin} from "../../interfaces/IAdmin.sol";
import {IVault} from "../../interfaces/IVault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Vault is IVault {
    address admin;

    constructor(address admin_) {
        admin = admin_;
    }

    modifier checkAuthority() {
        address msgSender = msg.sender;
        require(
            msgSender == IAdmin(admin).getLpPositionManager() ||
                msgSender == IAdmin(admin).getTradePositionManager()
        );
        _;
    }

    function withdrawalRequest(
        address token,
        address recipient,
        uint256 amount
    ) external checkAuthority {
        IERC20(token).transfer(recipient, amount);
    }
}
