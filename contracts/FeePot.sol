pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FeePot {
    using SafeERC20 for IERC20;

    address _owner;

    constructor(address owner) {
        _owner = owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Your not the owner");
        _;
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
