pragma solidity ^0.8.9;

import {IAdmin} from "../../interfaces/IAdmin.sol";
import {IVault} from "../../interfaces/IVault.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUSD} from "../../interfaces/IUSD.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Vault is IVault {
    using SafeMath for uint256;
    uint redeemFee = 5; //bp
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

    function redeem(uint amount) external {
        IUSD stablecoin = IUSD(IAdmin(admin).getStablecoin());
        IERC20 underlyingAsset = IERC20(stablecoin.underlyingAsset());

        require(
            stablecoin.balanceOf(msg.sender) >= amount,
            "Insufficient Sender Balance"
        );

        require(
            IERC20(underlyingAsset).balanceOf(address(this)) >= amount,
            "Insufficient Vault Balance"
        );

        stablecoin.burnFrom(msg.sender, amount);

        uint redeemAmount = (amount * (1e4 - 5)) / 1e4;
        uint fee = amount - redeemAmount;

        underlyingAsset.transfer(msg.sender, redeemAmount);
        underlyingAsset.transfer(IAdmin(admin).getFeePot(), fee);
    }
}
