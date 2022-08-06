pragma solidity ^0.8.9;

import "./PositionController.sol";
import "./LpToken.sol";
import "./Factory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LpPool is LpToken, ILpPool {
    address owner;
    address factory;
    address underlyingToken;

    uint80 public constant feeTierDenom = 10000;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp

    constructor(address _owner, address _underlyingToken) public {
        owner = _owner;
        underlyingToken = _underlyingToken;
        factory = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "You are not owner of this contract");
        _;
    }

    function addLiquidity(
        address user,
        uint256 depositQty,
        exchangerCall flag
    ) external returns (uint256 lpTokenQty) {
        if (flag == exchangerCall.yes) {
            require(
                msg.sender == Factory(factory).getPositionController(),
                "Not allowed to add liquidity as a trader"
            );
        }
        // amount to transfer is less than balance
        require(
            IERC20(underlyingToken).balanceOf(user) >= depositQty,
            "Not Enough Balance To Deposit"
        );

        // get lp token price
        uint256 lpTokenPrice = getPrice();

        // TODO charge fee (send 30% to fee pot)

        // TODO get number of token to mint

        // TODO mint token
        _mint();
    }

    function removeLiquidity(
        address user,
        uint256 lpTokenQty,
        exchangerCall flag
    ) external returns (uint256 withdrawQty) {
        if (flag == ILpPool.exchangerCall.yes) {
            require(
                msg.sender == Factory(factory).getPositionController(),
                "Not allowed to remove liquidity as a trader"
            );
        }

        // amount to transfer is less than balance
        require(
            IERC20(this).balanceOf(user) >= lpTokenQty,
            "Not Enough Balance To Withdraw"
        );

        // get lp token price
        uint256 lpTokenPrice = getPrice();
        // get fee tier of user

        // TODO get amount to burn and burn
        _burn();

        // TODO charge fee (send fee to fee pot)

        // TODO transfer amount to both fee pot and user
    }

    function getPrice(uint256 key) public view returns (uint256 _price) {
        // TODO supply: supply + unrealized pnl from position manager
        // TODO demand: USDC balance in this contract
    }

    function setFeeTier(uint80 fee, exchangerCall flag) external onlyOwner {
        if (flag == exchangerCall.yes) {
            defaultExchangeFeeTier = fee;
        } else if (flag == exchangerCall.no) {
            defaultLpFeeTier = fee;
        }
    }

    function getFeeTier(exchangerCall flag)
        external
        view
        returns (uint80 _fee, uint80 _feeTierDenom)
    {
        _fee = flag == exchangerCall.yes
            ? defaultExchangeFeeTier
            : defaultLpFeeTier;
        _feeTierDenom = feeTierDenom;
    }
}
