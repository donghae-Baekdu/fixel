pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IFactory.sol";

contract PositionController is ERC721Enumerable, Ownable {
    address ZD_TOKEN_ADDRESS = address(0);
    address USDC_TOKEN_ADDRESS = address(0);
    IERC20 USDC = IERC20(USDC_TOKEN_ADDRESS);

    mapping(uint80 => string) public markets;
    mapping(uint80 => uint32) public maxLeverage;
    uint80 marketCount;

    mapping(uint256 => address) private _tokenApprovals;
    mapping(uint256 => Position) positions;
    mapping(uint256 => MarketStatus) marketStatus;

    IFactory factoryContract;
    IPriceOracle priceOracle;

    //mocking
    ILpPool poolContract;
    //mocking

    event ChangeMaxLeverage(uint80 poolId, uint32 _maxLeverage);
    event AddMarket(uint80 marketCount, string name, uint32 _maxLeverage);

    enum Side {
        LONG,
        SHORT
    }

    struct Position {
        uint80 poolId;
        uint32 leverage;
        uint256 margin;
        uint256 price;
        Side side;
    }

    struct MarketStatus {
        uint256 margin;
        uint256 unrealizedPnl;
        uint256 totalLongPositionFactor;
        uint256 totalShortPositionFactor;
    }

    constructor(address _factoryContract)
        ERC721("Renaissance Position", "rPos")
    {
        factoryContract = IFactory(_factoryContract);
    }

    function openPosition(
        uint80 poolId,
        uint256 liquidity,
        uint32 leverage,
        Side side
    ) external {
        require(
            USDC.balanceOf(msg.sender) >= liquidity,
            "Insufficient Balance"
        );

        poolContract = ILpPool(factoryContract.getLpPool());
        USDC.transferFrom(msg.sender, address(this), liquidity);
        USDC.approve(address(poolContract), liquidity);

        uint256 margin = poolContract.addLiquidity(
            msg.sender,
            liquidity,
            IFactory.exchangerCall.yes
        );
        uint256 price = priceOracle.getPrice(poolId);

        require(leverage <= maxLeverage[poolId], "Excessive Leverage");

        uint256 tokenId = totalSupply();
        _mint(msg.sender, tokenId);
        positions[tokenId] = Position(poolId, leverage, margin, price, side);
    }

    function addMarket(string memory name, uint32 _maxLeverage)
        public
        onlyOwner
    {
        markets[marketCount] = name;
        maxLeverage[marketCount] = _maxLeverage;
        emit AddMarket(marketCount, name, _maxLeverage);
        marketCount = marketCount + 1;
    }

    function changeMaxLeverage(uint80 poolId, uint32 _maxLeverage)
        public
        onlyOwner
    {
        require(_maxLeverage > 0, "Max Leverage Should Be Positive");
        maxLeverage[poolId] = _maxLeverage;
        emit ChangeMaxLeverage(poolId, _maxLeverage);
    }

    function getMarketMaxLeverage(uint80 poolId)
        external
        view
        returns (uint32)
    {
        require(poolId < marketCount, "Invalid Pool Id");
        return maxLeverage[poolId];
    }
}
