pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FeePot is Ownable {
    function withdrawFee() external {
        // TODO transfer USDC to owner
    }

    receive() external payable {}
}
