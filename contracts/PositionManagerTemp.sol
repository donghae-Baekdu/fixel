pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IPositionManagerTemp.sol";
import "hardhat/console.sol";

//TODO: calculate funding fee -> complete
//TODO: apply funding fee when close position -> complete
//TODO: apply funding fee to liquidation condition -> complete

//TODO: change margin structure -> complete
//TODO: add modify position
//TODO: add sign to currentMargin, consider negative balance
contract PositionManagerTemp is Ownable, IPositionManagerTemp {
    using SafeMath for uint256;
    using SafeMath for uint32;

    uint256 public LEVERAGE_DECIMAL = 2;
    uint256 public FUNDING_RATE_DECIMAL = 4;

    address USDC_TOKEN_ADDRESS;

    IERC20 USDC;

    uint32 marketCount;

    mapping(uint32 => ValueWithSign) deltaFLPs;
    mapping(uint32 => ValueWithSign) notionalValueSum;

    //user -> marketId -> position
    mapping(address => mapping(uint32 => Position)) public positions;

    mapping(uint32 => MarketStatus) public marketStatus;
    mapping(uint32 => MarketInfo) public marketInfo;

    IFactory factoryContract;

    constructor(address factoryContract_, address usdc_) {
        factoryContract = IFactory(factoryContract_);
        USDC = IERC20(usdc_);
    }

    function openPosition(
        uint32 marketId,
        uint256 amount,
        bool isLong
    ) external {
        require(
            USDC.balanceOf(msg.sender) >= liquidity,
            "Insufficient Balance"
        );
        require(
            leverage <= marketInfo[marketId].maxLeverage,
            "Excessive Leverage"
        );
    }

    function closePosition(uint32 marketId, uint256 amount)
        external
        returns (uint256)
    {
        require(ownerOf(tokenId) == msg.sender, "Invalid Token Id");
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
    }

    function liquidate(uint32 marketId, uint256 tokenId) external {
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
    }

    function addMargin(
        uint256 tokenId,
        uint256 liquidity,
        uint256 notionalValue // value as usdc
    ) external {
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
    }

    function removeMargin(
        uint256 tokenId,
        uint256 margin,
        uint256 notionalValue
    ) external {
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
    }

    function collectTradingFee(uint256 tokenId, uint256 tradeAmount)
        internal
        returns (uint256 fee)
    {
        fee = ILpPool(factoryContract.getLpPool()).collectExchangeFee(
            tradeAmount
        );
        positions[tokenId].margin = positions[tokenId].margin.sub(fee);
    }

    function calculatePnl(
        uint256 initialPrice,
        uint256 currentPrice,
        uint256 notionalValue,
        bool isLong
    ) internal pure returns (bool _isPos, uint256 pnl) {
        uint256 denom = uint256(10000);
        if (currentPrice > initialPrice) {
            pnl = (currentPrice.sub(initialPrice))
                .mul(notionalValue)
                .div(initialPrice)
                .div(denom);

            _isPos = isLong;
        } else {
            pnl = (initialPrice.sub(currentPrice))
                .mul(notionalValue)
                .div(initialPrice)
                .div(denom);

            _isPos = !isLong;
        }
    }

    function calculateMargin(uint256 tokenId)
        public
        view
        returns (uint256 margin)
    {
        require(positions[tokenId].status == Status.OPEN, "Alread Closed");
        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(positions[tokenId].marketId);

        if (positions[tokenId].isLong == true) {
            if (currentPrice > positions[tokenId].price) {
                margin = positions[tokenId].margin.add(
                    (currentPrice.sub(positions[tokenId].price)).mul(
                        positions[tokenId].factor
                    )
                );
            } else {
                margin = positions[tokenId].margin.sub(
                    (positions[tokenId].price.sub(currentPrice)).mul(
                        positions[tokenId].factor
                    )
                );
            }
        } else {
            if (currentPrice > positions[tokenId].price) {
                margin = positions[tokenId].margin.sub(
                    (currentPrice.sub(positions[tokenId].price)).mul(
                        positions[tokenId].factor
                    )
                );
            } else {
                margin = positions[tokenId].margin.add(
                    (positions[tokenId].price.sub(currentPrice)).mul(
                        positions[tokenId].factor
                    )
                );
            }
        }
        margin = margin.sub(positions[tokenId].realizedMargin);
    }

    function calculateMarginWithFundingFee(uint256 tokenId)
        public
        view
        returns (uint256)
    {}

    function _closePosition(uint32 marketId, uint256 tokenId)
        internal
        returns (uint256)
    {}

    function updateMarketStatusAfterTrade(
        uint32 marketId,
        bool isLong,
        TradeType tradeType,
        //uint256 margin,
        uint256 factor
    ) internal {}

    function addMarket(
        string memory _name,
        uint32 _maxLeverage,
        uint32 _threshold
    ) public onlyOwner {
        marketInfo[marketCount].name = _name;
        marketInfo[marketCount].maxLeverage = _maxLeverage;
        marketInfo[marketCount].liquidationThreshold = _threshold;
        emit AddMarket(_name, marketCount, _maxLeverage);
        marketCount = marketCount + 1;
    }

    function changeMaxLeverage(uint32 marketId, uint32 _maxLeverage)
        public
        onlyOwner
    {
        require(_maxLeverage > 0, "Max Leverage Should Be Positive");
        require(marketId < marketCount, "Invalid Pool Id");
        marketInfo[marketId].maxLeverage = _maxLeverage;
        emit ChangeMaxLeverage(marketId, _maxLeverage);
    }

    function getMarketMaxLeverage(uint32 marketId)
        external
        view
        returns (uint32)
    {
        require(marketId < marketCount, "Invalid Pool Id");
        return marketInfo[marketId].maxLeverage;
    }

    function getTotalUnrealizedPnl()
        public
        view
        returns (bool isPositive, uint256 value)
    {}

    function applyUnrealizedPnl(uint32 marketId)
        public
        returns (Sign, uint256)
    {}

    function getUnrealizedPnl(uint32 marketId)
        public
        view
        returns (
            Sign isPositive,
            uint256 pnl,
            uint256 currentPrice
        )
    {}

    function getOwnedTokensIndex(address user, uint32 marketId)
        external
        view
        returns (uint256[] memory)
    {
        return userMarketPositions[user][marketId];
    }

    function calculatePositionFundingFee(uint256 tokenId)
        public
        view
        returns (Sign sign, uint256 fundingFee)
    {}

    function applyFundingRate(
        uint32 marketId,
        Sign sign,
        uint256 fundingRate
    ) external onlyOwner {}

    function calculateUnsignedAdd(
        Sign signA,
        uint256 numA,
        Sign signB,
        uint256 numB
    ) internal pure returns (Sign resSign, uint256 resNum) {}

    function calculateUnsignedSub(
        Sign signA,
        uint256 numA,
        Sign signB,
        uint256 numB
    ) internal pure returns (Sign resSign, uint256 resNum) {
        if (signA != signB) {
            return (signA, numA.add(numB));
        } else {
            if (numA > numB) {
                return (signA, numA.sub(numB));
            } else {
                if (signA == Sign.POS) {
                    return (Sign.NEG, numB.sub(numA));
                } else {
                    return (Sign.POS, numB.sub(numA));
                }
            }
        }
    }

    function _addTokenToUserPositions(
        address user,
        uint32 marketId,
        uint256 tokenId
    ) private {
        userMarketPositionsIndex[user][tokenId] = userMarketPositions[user][
            marketId
        ].length;
        userMarketPositions[user][marketId].push(tokenId);
    }

    function _removeTokenFromUserPositions(
        address user,
        uint32 marketId,
        uint256 tokenId
    ) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = userMarketPositions[user][marketId].length - 1;
        uint256 tokenIndex = userMarketPositionsIndex[user][tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = userMarketPositions[user][marketId][
            lastTokenIndex
        ];

        userMarketPositions[user][marketId][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        userMarketPositionsIndex[user][lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete userMarketPositionsIndex[user][tokenId];
        userMarketPositions[user][marketId].pop();
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        if (from == address(0)) {
            _addTokenToUserPositions(to, positions[tokenId].marketId, tokenId);
        } else if (to == address(0)) {
            _removeTokenFromUserPositions(
                from,
                positions[tokenId].marketId,
                tokenId
            );
        } else {
            _addTokenToUserPositions(to, positions[tokenId].marketId, tokenId);
            _removeTokenFromUserPositions(
                from,
                positions[tokenId].marketId,
                tokenId
            );
        }
    }
}
