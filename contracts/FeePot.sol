pragma solidity ^0.8.9;

<<<<<<< HEAD
=======
import "./Position.sol";
>>>>>>> 373ee13 (Brief design)
import "@openzeppelin/contracts/access/Ownable.sol";

contract FeePot is Ownable {
    function withdrawFee() public {
<<<<<<< HEAD
        // TODO transfer USDC to owner
=======
        // TODO send USDC to owner
>>>>>>> 373ee13 (Brief design)
    }

    receive() external payable {}
}
