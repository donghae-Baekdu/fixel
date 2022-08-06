pragma solidity ^0.8.9;

<<<<<<< HEAD
<<<<<<< HEAD
import "./PositionController.sol";
import "./LpToken.sol";
import "./Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

<<<<<<< HEAD
contract LpPool is LpToken {
    enum exchangerCall {
        yes,
        no
    }

    mapping(address => uint) public feeTier;
    address owner;
    address factory;
    address exchanger;

    constructor(address _owner) public {
        owner = _owner;
        factory = msg.sender;
    }

    function addLiquidity(
        address user,
        uint256 marginQty,
        exchangerCall flag
    ) public returns (uint256 lpTokenQty) {
        if (flag == exchangerCall.yes) {
            // require(msg.sender == )
        }
        // TODO get price
        uint256 lpTokenPrice = getPrice();
        // TODO get fee tier of user
        (uint80 feeTier, uint80 feeTierDenom) = Factory(factory).getFeeTier(
            user
        );
        // TODO check requirements; amount to transfer is less than balance
        // TODO mint amount of token
    }

    function removeLiquidity(uint256 lpTokenQty)
        public
        returns (uint256 marginQty)
    {
        // TODO get price
        // TODO check requirements; amount to transfer is less than balance
        // TODO burn amount of token
=======
contract LpPool {
=======
import "./Position.sol";
=======
import "./PositionController.sol";
>>>>>>> d897937 (Implement Factory Pattern)
import "./LpToken.sol";
import "./Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LpPool is LpToken {
    enum exchangerCall {
        yes,
        no
    }

    mapping(address => uint) public feeTier;
    address owner;
    address factory;
    address exchanger;

<<<<<<< HEAD
<<<<<<< HEAD
contract LpPool is LpToken {
>>>>>>> 506a2d4 (Design Lp pool architecture)
=======
>>>>>>> 4dc0db3 (Going to office)
    function addLiquidity(uint256 marginQty)
        public
        returns (uint256 lpTokenQty)
    {
=======
    constructor(address _owner) public {
        owner = _owner;
        factory = msg.sender;
    }

    function addLiquidity(
        address user,
        uint256 marginQty,
        exchangerCall flag
    ) public returns (uint256 lpTokenQty) {
        if (flag == exchangerCall.yes) {
            // require(msg.sender == )
        }
>>>>>>> d897937 (Implement Factory Pattern)
        // TODO get price
        uint256 lpTokenPrice = getPrice();
        // TODO get fee tier of user
        (uint80 feeTier, uint80 feeTierDenom) = Factory(factory).getFeeTier(
            user
        );
        // TODO check requirements; amount to transfer is less than balance
        // TODO mint amount of token
    }

    function removeLiquidity(uint256 lpTokenQty)
        public
        returns (uint256 marginQty)
    {
        // TODO get price
        // TODO check requirements; amount to transfer is less than balance
        // TODO burn amount of token
    }

<<<<<<< HEAD
    function mint() public {
        // TODO mint amount of token; refer synthetix kwenta
    }

    function burn() public {
        // TODO burn amount of token; refer synthetix kwenta
>>>>>>> 373ee13 (Brief design)
    }

=======
>>>>>>> 506a2d4 (Design Lp pool architecture)
    function getPrice() public view returns (uint256 _price) {
        // TODO supply: supply + unrealized pnl from position manager
        // TODO demand: USDC balance in this contract
    }
}
