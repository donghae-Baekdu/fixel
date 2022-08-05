pragma solidity ^0.8.9;

import "./Position.sol";

contract FeePot {
    function withdrawFee() public {}

    receive() external payable {}
}
