pragma solidity ^0.8.9;

import "./Position.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FeePot is Ownable {
    function withdrawFee() public {
        // TODO send USDC to owner
    }

    receive() external payable {}
}
