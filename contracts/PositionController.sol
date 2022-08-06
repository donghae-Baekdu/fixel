pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IPositionController.sol";

contract PositionController is ERC721Enumerable, Ownable, IPositionController {
    using SafeMath for uint256;

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

    constructor(address _factoryContract)
        ERC721("Renaissance Position", "rPos")
    {
        factoryContract = IFactory(_factoryContract);
    }

    function openPosition(
        uint80 marketId,
        uint256 liquidity,
        uint32 leverage,
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

        USDC.transferFrom(msg.sender, address(this), liquidity);
        USDC.approve(address(poolContract), liquidity);

        uint256 margin = poolContract.addLiquidity(
            msg.sender,
            liquidity,
            ILpPool.exchangerCall.yes
        );
        uint256 price = priceOracle.getPrice(marketId);

        require(leverage <= maxLeverage[marketId], "Excessive Leverage");

        uint256 tokenId = totalSupply();
        _mint(msg.sender, tokenId);
        positions[tokenId] = Position(marketId, leverage, margin, price, side);
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

    function changeMaxLeverage(uint80 marketId, uint32 _maxLeverage)
        public
        onlyOwner
    {
        require(_maxLeverage > 0, "Max Leverage Should Be Positive");
        require(marketId < marketCount, "Invalid Pool Id");
        maxLeverage[marketId] = _maxLeverage;
        emit ChangeMaxLeverage(marketId, _maxLeverage);
    }

    function getMarketMaxLeverage(uint80 marketId)
        external
        view
        returns (uint32)
    {
        require(marketId < marketCount, "Invalid Pool Id");
        return maxLeverage[marketId];
    }

    function applyUnrealizedPnl(uint80 marketId)
        external
        returns (Sign, uint256)
    {
        require(marketId < marketCount, "Invalid Pool Id");
        if (marketStatus[marketId].lastBlockNumber == block.number) {
            return (
                marketStatus[marketId].pnlSign,
                marketStatus[marketId].unrealizedPnl
            );
        }
        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(marketId);

        if (marketStatus[marketId].lastPrice < currentPrice) {
            uint256 longPositionsProfit = marketStatus[marketId]
                .totalLongPositionFactor
                .mul(currentPrice.sub(marketStatus[marketId].lastPrice));
            uint256 shortPositionsLoss = marketStatus[marketId]
                .totalShortPositionFactor
                .mul(currentPrice.sub(marketStatus[marketId].lastPrice));

            if (longPositionsProfit > shortPositionsLoss) {
                uint256 profit = longPositionsProfit.sub(shortPositionsLoss);
                if (marketStatus[marketId].pnlSign == Sign.POS) {
                    marketStatus[marketId].unrealizedPnl = marketStatus[
                        marketId
                    ].unrealizedPnl.add(profit);
                } else {
                    if (marketStatus[marketId].unrealizedPnl < profit) {
                        marketStatus[marketId].pnlSign = Sign.POS;
                        marketStatus[marketId].unrealizedPnl = profit.sub(
                            marketStatus[marketId].unrealizedPnl
                        );
                    } else {
                        marketStatus[marketId].unrealizedPnl = marketStatus[
                            marketId
                        ].unrealizedPnl.sub(profit);
                    }
                }
            } else {
                uint256 loss = shortPositionsLoss.sub(longPositionsProfit);
                if (marketStatus[marketId].pnlSign == Sign.NEG) {
                    marketStatus[marketId].unrealizedPnl = marketStatus[
                        marketId
                    ].unrealizedPnl.add(loss);
                } else {
                    if (marketStatus[marketId].unrealizedPnl < loss) {
                        marketStatus[marketId].pnlSign = Sign.NEG;
                        marketStatus[marketId].unrealizedPnl = loss.sub(
                            marketStatus[marketId].unrealizedPnl
                        );
                    } else {
                        marketStatus[marketId].unrealizedPnl = marketStatus[
                            marketId
                        ].unrealizedPnl.sub(loss);
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
                uint256 profit = shortPositionsProfit.sub(longPositionsLoss);
                if (marketStatus[marketId].pnlSign == Sign.POS) {
                    marketStatus[marketId].unrealizedPnl = marketStatus[
                        marketId
                    ].unrealizedPnl.add(profit);
                } else {
                    if (marketStatus[marketId].unrealizedPnl < profit) {
                        marketStatus[marketId].pnlSign = Sign.POS;
                        marketStatus[marketId].unrealizedPnl = profit.sub(
                            marketStatus[marketId].unrealizedPnl
                        );
                    } else {
                        marketStatus[marketId].unrealizedPnl = marketStatus[
                            marketId
                        ].unrealizedPnl.sub(profit);
                    }
                }
            } else {
                uint256 loss = longPositionsLoss.sub(shortPositionsProfit);
                if (marketStatus[marketId].pnlSign == Sign.NEG) {
                    marketStatus[marketId].unrealizedPnl = marketStatus[
                        marketId
                    ].unrealizedPnl.add(loss);
                } else {
                    if (marketStatus[marketId].unrealizedPnl < loss) {
                        marketStatus[marketId].pnlSign = Sign.NEG;
                        marketStatus[marketId].unrealizedPnl = loss.sub(
                            marketStatus[marketId].unrealizedPnl
                        );
                    } else {
                        marketStatus[marketId].unrealizedPnl = marketStatus[
                            marketId
                        ].unrealizedPnl.sub(loss);
                    }
                }
            }
        }
        marketStatus[marketId].lastPrice = currentPrice;
        marketStatus[marketId].lastBlockNumber = block.number;
        return (
            marketStatus[marketId].pnlSign,
            marketStatus[marketId].unrealizedPnl
        );
    }

    function getUnrealizedPnl(uint80 marketId)
        external
        view
        returns (Sign isPositive, uint256 pnl)
    {
        require(marketId < marketCount, "Invalid Pool Id");
        if (marketStatus[marketId].lastBlockNumber == block.number) {
            return (
                marketStatus[marketId].pnlSign,
                marketStatus[marketId].unrealizedPnl
            );
        }
        isPositive = marketStatus[marketId].pnlSign;

        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(marketId);

        if (marketStatus[marketId].lastPrice < currentPrice) {
            uint256 longPositionsProfit = marketStatus[marketId]
                .totalLongPositionFactor
                .mul(currentPrice.sub(marketStatus[marketId].lastPrice));
            uint256 shortPositionsLoss = marketStatus[marketId]
                .totalShortPositionFactor
                .mul(currentPrice.sub(marketStatus[marketId].lastPrice));

            if (longPositionsProfit > shortPositionsLoss) {
                uint256 profit = longPositionsProfit.sub(shortPositionsLoss);
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
                uint256 loss = shortPositionsLoss.sub(longPositionsProfit);
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
                uint256 profit = shortPositionsProfit.sub(longPositionsLoss);
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
                uint256 loss = longPositionsLoss.sub(shortPositionsProfit);
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
}
