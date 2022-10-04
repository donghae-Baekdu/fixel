pragma solidity ^0.8.9;

import {IAdmin} from "../../interfaces/IAdmin.sol";
import {IVault} from "../../interfaces/IVault.sol";
import {IUSD} from "../../interfaces/IUSD.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {MathUtil} from "../../libraries/MathUtil.sol";

contract Vault is IVault {
    using SafeMath for uint256;
    uint redeemFee = 5; //bp
    address admin;
    address USDC;
    uint256 cumulatedFee;

    constructor(address admin_, address USDC_) {
        admin = admin_;
        USDC = USDC_;
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

    // Note. assume xUSD and USDC decimals are same
    function redeem(uint burnAmount) external {
        IUSD stablecoin = IUSD(IAdmin(admin).getStablecoin());

        require(
            stablecoin.balanceOf(msg.sender) >= burnAmount,
            "Insufficient Sender Balance"
        );

        uint256 redeemAmount = (burnAmount * (1e4 - 5)) / 1e4;

        require(
            IERC20(USDC).balanceOf(address(this)) >= redeemAmount,
            "Insufficient Vault Balance"
        );

        IERC20(USDC).transfer(msg.sender, redeemAmount);

        stablecoin.burn(msg.sender, burnAmount);

        uint256 fee = burnAmount - redeemAmount;
        cumulatedFee += fee;
    }

    function wrap() external {
        // TODO wrap USDC to xUSD
    }

    function cumulateProtocolFee(uint256 amount) external checkAuthority {
        cumulatedFee += amount;
    }
}
