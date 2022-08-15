pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FeePot is Ownable{
    using SafeERC20 for IERC20;
    
    constructor() {
    }

    function withdrawFee(
        address to,
        address asset,
        uint256 value
    ) external onlyOwner {
        // TODO transfer USDC to owner
        IERC20(asset).safeTransferFrom(address(this), to, value);
    }

    receive() external payable {}
}
