pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IPositionController.sol";
import "hardhat/console.sol";

contract PositionController is ERC721Enumerable, Ownable, IPositionController {
    using SafeMath for uint256;
    using SafeMath for uint32;

    uint256 public LEVERAGE_DECIMAL = 2;

    address GD_TOKEN_ADDRESS;
    address USDC_TOKEN_ADDRESS;

    IERC20 USDC;
    IERC20 GD;

    uint32 marketCount;

    mapping(uint256 => Position) public positions;

    mapping(address => mapping (uint32 => uint256[])) public userMarketPositions;
    //user -> tokenId -> index
    mapping(address => mapping(uint256 => uint256)) public userMarketPositionsIndex;

    mapping(uint32 => MarketStatus) public marketStatus;
    mapping(uint32 => MarketInfo) public marketInfo;

    IFactory factoryContract;

    constructor(address _factoryContract, address _usdc, address _gd)
        ERC721("Renaissance Position", "rPos")
    {
        factoryContract = IFactory(_factoryContract);
        USDC = IERC20(_usdc);
        GD = IERC20(_gd);
    }

    function openPosition(
        uint32 marketId,
        uint32 leverage,
        uint256 liquidity,
        Side side
    ) external {
        require(
            USDC.balanceOf(msg.sender) >= liquidity,
            "Insufficient Balance"
        );

        ILpPool poolContract = ILpPool(factoryContract.getLpPool());
        IPriceOracle priceOracle = IPriceOracle(
            factoryContract.getPriceOracle()
        );

        uint256 margin = poolContract.addLiquidity(
            msg.sender,
            liquidity,
            ILpPool.exchangerCall.yes
        );
        uint256 price = priceOracle.getPrice(marketId);

        require(leverage <= marketInfo[marketId].maxLeverage, "Excessive Leverage");

        uint256 tokenId = totalSupply();
        _mint(msg.sender, tokenId);
        positions[tokenId] = Position(
            marketId,
            leverage,
            margin,
            price,
            uint256(0),
            side,
            Status.OPEN
        );
        
        updateMarketStatusAfterTrade(
            marketId,
            side,
            TradeType.OPEN,
            margin,
            margin.mul(leverage).div(price)
        );

        emit OpenPosition(
            msg.sender,
            marketId,
            leverage,
            side,
            margin,
            tokenId
        );
    }

    function closePosition(uint32 marketId, uint256 tokenId) external returns (uint256) {
        require(ownerOf(tokenId) == msg.sender, "Invalid Token Id");
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
        uint256 receiveAmount = _closePosition(marketId, tokenId);
        console.log(receiveAmount);
        return receiveAmount;
    }

    function liquidate(uint32 marketId, uint256 tokenId) external {
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
        uint256 currentMargin = calculateMargin(tokenId);
        uint256 marginRatio = currentMargin.mul(uint256(10000)).div(
            positions[tokenId].margin
        );
        require(
            marginRatio < marketInfo[marketId].liquidationThreshold,
            "Not Liquidatable"
        );
        uint256 returnAmount = _closePosition(marketId, tokenId);
        USDC.transfer(msg.sender, returnAmount);
        emit Liquidation(ownerOf(tokenId), msg.sender, marketId, tokenId);
    }

    function calculateMargin(uint256 tokenId) public view returns (uint256) {
        require(positions[tokenId].status == Status.OPEN, "Alread Closed");
        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(positions[tokenId].marketId);
        uint256 multiplier = positions[tokenId]
            .leverage
            .mul(positions[tokenId].margin)
            .div(positions[tokenId].price)
            .div(uint256(10)**LEVERAGE_DECIMAL);
        if (positions[tokenId].side == Side.LONG) {
            if (currentPrice > positions[tokenId].price) {
                return
                    positions[tokenId].margin.add(
                        (currentPrice.sub(positions[tokenId].price)).mul(
                            multiplier
                        )
                    );
            } else {
                return
                    positions[tokenId].margin.sub(
                        (positions[tokenId].price.sub(currentPrice)).mul(
                            multiplier
                        )
                    );
            }
        } else {
            if (currentPrice > positions[tokenId].price) {
                return
                    positions[tokenId].margin.sub(
                        (currentPrice.sub(positions[tokenId].price)).mul(
                            multiplier
                        )
                    );
            } else {
                return
                    positions[tokenId].margin.add(
                        (positions[tokenId].price.sub(currentPrice)).mul(
                            multiplier
                        )
                    );
            }
        }
    }

    function _closePosition(uint32 marketId, uint256 tokenId)
        internal
        returns (uint256)
    {
        updateMarketStatusAfterTrade(
            marketId,
            positions[tokenId].side,
            TradeType.CLOSE,
            positions[tokenId].margin,
            positions[tokenId].margin.mul(positions[tokenId].leverage).div(
                positions[tokenId].price
            )
        );

        bool isProfit;
        uint256 pnl;
        uint256 factor = positions[tokenId]
            .margin
            .mul(positions[tokenId].leverage)
            .div(positions[tokenId].price);

        if (positions[tokenId].side == Side.LONG) {
            if (marketStatus[marketId].lastPrice > positions[tokenId].price) {
                isProfit = true;
                pnl = (
                    marketStatus[marketId].lastPrice.sub(
                        positions[tokenId].price
                    )
                ).mul(factor).div(uint256(10)**LEVERAGE_DECIMAL);
            } else {
                isProfit = false;
                pnl = (
                    positions[tokenId].price.sub(
                        marketStatus[marketId].lastPrice
                    )
                ).mul(factor).div(uint256(10)**LEVERAGE_DECIMAL);
            }
        } else {
            if (marketStatus[marketId].lastPrice > positions[tokenId].price) {
                isProfit = false;
                pnl = (
                    marketStatus[marketId].lastPrice.sub(
                        positions[tokenId].price
                    )
                ).mul(factor).div(uint256(10)**LEVERAGE_DECIMAL);
            } else {
                isProfit = true;
                pnl = (
                    positions[tokenId].price.sub(
                        marketStatus[marketId].lastPrice
                    )
                ).mul(factor).div(uint256(10)**LEVERAGE_DECIMAL);
            }
        }

        uint256 refundGd;
      
        ILpPool lpPool = ILpPool(factoryContract.getLpPool());

        if (isProfit) {
            (marketStatus[marketId].pnlSign, marketStatus[marketId].unrealizedPnl) = calculateUnsignedSum(marketStatus[marketId].pnlSign,marketStatus[marketId].unrealizedPnl,Sign.NEG, pnl);
            lpPool.mint(address(this), pnl);
            refundGd = positions[tokenId].margin.add(pnl);
        } else {
            (marketStatus[marketId].pnlSign, marketStatus[marketId].unrealizedPnl) = calculateUnsignedSum(marketStatus[marketId].pnlSign,marketStatus[marketId].unrealizedPnl,Sign.POS, pnl);
            uint256 burnAmount = pnl > positions[marketId].margin
                ? positions[marketId].margin
                : pnl;
            lpPool.burn(address(this), burnAmount);
            refundGd = positions[tokenId].margin.sub(burnAmount);
        }
      
        positions[tokenId].status = Status.CLOSE;
        positions[tokenId].closePrice = marketStatus[marketId].lastPrice;

        uint256 receiveAmount = lpPool.removeLiquidity(
            ownerOf(tokenId),
            refundGd,
            ILpPool.exchangerCall.yes
        );
        emit ClosePosition(
            ownerOf(tokenId),
            marketId,
            positions[tokenId].side,
            isProfit,
            tokenId,
            positions[tokenId].margin,
            pnl,
            receiveAmount
        );
        return receiveAmount;
    }

    function updateMarketStatusAfterTrade(
        uint32 marketId,
        Side side,
        TradeType tradeType,
        uint256 margin,
        uint256 factor
    ) internal {
        applyUnrealizedPnl(marketId);
        if (tradeType == TradeType.OPEN) {
            marketStatus[marketId].margin = marketStatus[marketId].margin.add(
                margin
            );
            if (side == Side.LONG) {
                marketStatus[marketId].totalLongPositionFactor = marketStatus[
                    marketId
                ].totalLongPositionFactor.add(factor);
            } else {
                marketStatus[marketId].totalShortPositionFactor = marketStatus[
                    marketId
                ].totalShortPositionFactor.add(factor);
            }
        } else if (tradeType == TradeType.CLOSE) {
            marketStatus[marketId].margin = marketStatus[marketId].margin.sub(
                margin
            );
            if (side == Side.LONG) {
                marketStatus[marketId].totalLongPositionFactor = marketStatus[
                    marketId
                ].totalLongPositionFactor.sub(factor);
            } else {
                marketStatus[marketId].totalShortPositionFactor = marketStatus[
                    marketId
                ].totalShortPositionFactor.sub(factor);
            }
        }
    }

    function addMarket(
        string memory _name,
        uint32 _maxLeverage,
        uint32 _threshold
    ) public onlyOwner {
        marketInfo[marketCount].name = _name;
        marketInfo[marketCount].maxLeverage = _maxLeverage;
        marketInfo[marketCount].liquidationThreshold = _threshold;
        emit AddMarket(_name,marketCount, _maxLeverage);
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
    {
        uint256 totalProfit = 0;
        uint256 totalLoss = 0;
        for (uint32 i = 0; i < marketCount; i = i + 1) {
            (Sign sign, uint256 pnl, ) = getUnrealizedPnl(i);
            if (sign == Sign.POS) {
                totalProfit = totalProfit.add(pnl);
            } else {
                totalLoss = totalLoss.add(pnl);
            }
        }
        if (totalProfit > totalLoss) {
            isPositive = true;
            value = totalProfit.sub(totalLoss);
        } else {
            isPositive = false;
            value = totalLoss.sub(totalProfit);
        }
    }

    function applyUnrealizedPnl(uint32 marketId)
        public
        returns (Sign, uint256)
    {
        require(marketId < marketCount, "Invalid Pool Id");
        (Sign isPositive, uint256 pnl, uint256 currentPrice) = getUnrealizedPnl(
            marketId
        );
        marketStatus[marketId].lastPrice = currentPrice;
        marketStatus[marketId].lastBlockNumber = block.number;
        marketStatus[marketId].pnlSign = isPositive;
        marketStatus[marketId].unrealizedPnl = pnl;
        return (
            marketStatus[marketId].pnlSign,
            marketStatus[marketId].unrealizedPnl
        );
    }

    function getUnrealizedPnl(uint32 marketId)
        public
        view
        returns (
            Sign isPositive,
            uint256 pnl,
            uint256 currentPrice
        )
    {
        require(marketId < marketCount, "Invalid Pool Id");

        currentPrice = IPriceOracle(factoryContract.getPriceOracle()).getPrice(
            marketId
        );

        if (marketStatus[marketId].lastBlockNumber == block.number) {
            return (
                marketStatus[marketId].pnlSign,
                marketStatus[marketId].unrealizedPnl,
                currentPrice
            );
        }
        isPositive = marketStatus[marketId].pnlSign;

        if (marketStatus[marketId].lastPrice < currentPrice) {
            uint256 longPositionsProfit = marketStatus[marketId]
                .totalLongPositionFactor
                .mul(currentPrice.sub(marketStatus[marketId].lastPrice));
            uint256 shortPositionsLoss = marketStatus[marketId]
                .totalShortPositionFactor
                .mul(currentPrice.sub(marketStatus[marketId].lastPrice));

            if (longPositionsProfit > shortPositionsLoss) {
                uint256 profit = (longPositionsProfit.sub(shortPositionsLoss))
                    .div(uint256(10)**LEVERAGE_DECIMAL);
                if (marketStatus[marketId].pnlSign == Sign.POS) {
                    pnl = marketStatus[marketId].unrealizedPnl.add(profit);
                } else {
                    if (marketStatus[marketId].unrealizedPnl < profit) {
                        isPositive = Sign.POS;
                        pnl = profit.sub(marketStatus[marketId].unrealizedPnl);
                    } else {
                        pnl = marketStatus[marketId].unrealizedPnl.sub(profit);
                    }
                }
            } else {
                uint256 loss = (shortPositionsLoss.sub(longPositionsProfit))
                    .div(uint256(10)**LEVERAGE_DECIMAL);
                if (marketStatus[marketId].pnlSign == Sign.NEG) {
                    pnl = marketStatus[marketId].unrealizedPnl.add(loss);
                } else {
                    if (marketStatus[marketId].unrealizedPnl < loss) {
                        isPositive = Sign.NEG;
                        pnl = loss.sub(marketStatus[marketId].unrealizedPnl);
                    } else {
                        pnl = marketStatus[marketId].unrealizedPnl.sub(loss);
                    }
                }
            }
        } else {
            uint256 longPositionsLoss = marketStatus[marketId]
                .totalLongPositionFactor
                .mul(marketStatus[marketId].lastPrice.sub(currentPrice));
            uint256 shortPositionsProfit = marketStatus[marketId]
                .totalShortPositionFactor
                .mul(marketStatus[marketId].lastPrice.sub(currentPrice));

            if (shortPositionsProfit > longPositionsLoss) {
                uint256 profit = (shortPositionsProfit.sub(longPositionsLoss))
                    .div(uint256(10)**LEVERAGE_DECIMAL);
                if (marketStatus[marketId].pnlSign == Sign.POS) {
                    pnl = marketStatus[marketId].unrealizedPnl.add(profit);
                } else {
                    if (marketStatus[marketId].unrealizedPnl < profit) {
                        isPositive = Sign.POS;
                        pnl = profit.sub(marketStatus[marketId].unrealizedPnl);
                    } else {
                        pnl = marketStatus[marketId].unrealizedPnl.sub(profit);
                    }
                }
            } else {
                uint256 loss = (longPositionsLoss.sub(shortPositionsProfit))
                    .div(uint256(10)**LEVERAGE_DECIMAL);
                if (marketStatus[marketId].pnlSign == Sign.NEG) {
                    pnl = marketStatus[marketId].unrealizedPnl.add(loss);
                } else {
                    if (marketStatus[marketId].unrealizedPnl < loss) {
                        isPositive = Sign.NEG;
                        pnl = loss.sub(marketStatus[marketId].unrealizedPnl);
                    } else {
                        pnl = marketStatus[marketId].unrealizedPnl.sub(loss);
                    }
                }
            }
        }
    }
    
    function getOwnedTokensIndex(address user, uint32 marketId) view external returns (uint256[] memory) {
        return userMarketPositions[user][marketId];
    }

    function calculateUnsignedSum(Sign signA, uint256 numA, Sign signB, uint256 numB) internal returns(Sign resSign, uint256 resNum){
        if(signA == signB){
            return (signA, numA.add(numB));
        } else{
            if(numA > numB){
                return (signA, numA.sub(numB));
            } else {
                return (signB, numB.sub(numA));
            }
        }
    }

    function _addTokenToUserPositions(address user, uint32 marketId, uint256 tokenId) private {
        userMarketPositionsIndex[user][tokenId] = userMarketPositions[user][marketId].length;
        userMarketPositions[user][marketId].push(tokenId);
    }

    function _removeTokenFromUserPositions(address user, uint32 marketId, uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = userMarketPositions[user][marketId].length - 1;
        uint256 tokenIndex = userMarketPositionsIndex[user][tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = userMarketPositions[user][marketId][lastTokenIndex];

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
        if(from == address(0)){
            _addTokenToUserPositions(to, positions[tokenId].marketId, tokenId);
        } else if(to == address(0)){
            _removeTokenFromUserPositions(from, positions[tokenId].marketId, tokenId);
        } else {
            _addTokenToUserPositions(to, positions[tokenId].marketId, tokenId);
            _removeTokenFromUserPositions(from, positions[tokenId].marketId, tokenId);
        }
    }
}
