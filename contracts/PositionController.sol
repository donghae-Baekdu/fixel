pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IFactory.sol";

contract PositionController is ERC721Enumerable, Ownable {
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

    event ChangeMaxLeverage(uint80 marketId, uint32 _maxLeverage);
    event AddMarket(uint80 marketCount, string name, uint32 _maxLeverage);

    enum Side {
        LONG,
        SHORT
    }

    enum Sign {
        POS,
        NEG
    }

    struct Position {
        uint80 marketId;
        uint32 leverage;
        uint256 margin;
        uint256 price;
        Side side;
    }

    struct MarketStatus {
        uint256 margin;
        Sign pnlSign;
        uint256 unrealizedPnl;
        uint256 totalLongPositionFactor;
        uint256 totalShortPositionFactor;
        uint256 lastPrice;
        uint256 lastBlockNumber;
    }

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

        poolContract = ILpPool(factoryContract.getLpPool());
        priceOracle = IPriceOracle(factoryContract.getPriceOracle());

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
        returns (bool, uint256)
    {
        require(marketId < marketCount, "Invalid Pool Id");
        if (marketStatus.lastBlockNumber == block.number) {
            return [marketStatus.pnlSign, marketStatus.unrealizedPnl];
        }
        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(marketId);

        if (marketStatus.lastPrice < currentPrice) {
            uint256 longPositionsProfit = marketStatus
                .totalLongPositionFactor
                .mul(currentPrice.sub(marketStatus.lastPrice));
            uint256 shortPositionsLoss = marketStatus
                .totalShortPositionFactor
                .mul(currentPrice.sub(marketStatus.lastPrice));

            if (longPositionsProfit > shortPositionsLoss) {
                uint256 profit = longPositionsProfit.sub(shortPositionsLoss);
                if (marketStatus.pnlSign == Sign.POS) {
                    marketStatus.unrealizedPnl = marketStatus.unrealizedPnl.add(
                        profit
                    );
                } else {
                    if (marketStatus.unrealizedPnl < profit) {
                        marketStatus.pnlSign = Sign.POS;
                        marketStatus.unrealizedPnl = profit.sub(
                            marketStatus.unrealizedPnl
                        );
                    } else {
                        marketStatus.unrealizedPnl = marketStatus
                            .unrealizedPnl
                            .sub(profit);
                    }
                }
            } else {
                uint256 loss = shortPositionsLoss.sub(longPositionsProfit);
                if (marketStatus.pnlSign == Sign.NEG) {
                    marketStatus.unrealizedPnl = marketStatus.unrealizedPnl.add(
                        loss
                    );
                } else {
                    if (marketStatus.unrealizedPnl < loss) {
                        marketStatus.pnlSign = Sign.NEG;
                        marketStatus.unrealizedPnl = loss.sub(
                            marketStatus.unrealizedPnl
                        );
                    } else {
                        marketStatus.unrealizedPnl = marketStatus
                            .unrealizedPnl
                            .sub(loss);
                    }
                }
            }
        } else {
            uint256 longPositionsLoss = marketStatus
                .totalLongPositionFactor
                .mul(marketStatus.lastPrice.sub(currentPrice));
            uint256 shortPositionsProfit = marketStatus
                .totalShortPositionFactor
                .mul(marketStatus.lastPrice.sub(currentPrice));

            if (shortPositionsProfit > longPositionsLoss) {
                uint256 profit = shortPositionsProfit.sub(longPositionsLoss);
                if (marketStatus.pnlSign == Sign.POS) {
                    marketStatus.unrealizedPnl = marketStatus.unrealizedPnl.add(
                        profit
                    );
                } else {
                    if (marketStatus.unrealizedPnl < profit) {
                        marketStatus.pnlSign = Sign.POS;
                        marketStatus.unrealizedPnl = profit.sub(
                            marketStatus.unrealizedPnl
                        );
                    } else {
                        marketStatus.unrealizedPnl = marketStatus
                            .unrealizedPnl
                            .sub(profit);
                    }
                }
            } else {
                uint256 loss = longPositionsLoss.sub(shortPositionsProfit);
                if (marketStatus.pnlSign == Sign.NEG) {
                    marketStatus.unrealizedPnl = marketStatus.unrealizedPnl.add(
                        loss
                    );
                } else {
                    if (marketStatus.unrealizedPnl < loss) {
                        marketStatus.pnlSign = Sign.NEG;
                        marketStatus.unrealizedPnl = loss.sub(
                            marketStatus.unrealizedPnl
                        );
                    } else {
                        marketStatus.unrealizedPnl = marketStatus
                            .unrealizedPnl
                            .sub(loss);
                    }
                }
            }
        }
        marketStatus.lastPrice = currentPrice;
        marketStatus.lastBlockNumber = block.number;
        return [marketStatus.pnlSign, marketStatus.unrealizedPnl];
    }

    function getUnrealizedPnl(uint80 marketId)
        external
        view
        returns (bool isPositive, uint256 pnl)
    {
        require(marketId < marketCount, "Invalid Pool Id");
        if (marketStatus.lastBlockNumber == block.number) {
            return [marketStatus.pnlSign, marketStatus.unrealizedPnl];
        }
        isPositive = marketStatus.pnlSign;

        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(marketId);

        if (marketStatus.lastPrice < currentPrice) {
            uint256 longPositionsProfit = marketStatus
                .totalLongPositionFactor
                .mul(currentPrice.sub(marketStatus.lastPrice));
            uint256 shortPositionsLoss = marketStatus
                .totalShortPositionFactor
                .mul(currentPrice.sub(marketStatus.lastPrice));

            if (longPositionsProfit > shortPositionsLoss) {
                uint256 profit = longPositionsProfit.sub(shortPositionsLoss);
                if (marketStatus.pnlSign == Sign.POS) {
                    pnl = marketStatus.unrealizedPnl.add(profit);
                } else {
                    if (marketStatus.unrealizedPnl < profit) {
                        isPositive = Sign.POS;
                        pnl = profit.sub(marketStatus.unrealizedPnl);
                    } else {
                        pnl = marketStatus.unrealizedPnl.sub(profit);
                    }
                }
            } else {
                uint256 loss = shortPositionsLoss.sub(longPositionsProfit);
                if (marketStatus.pnlSign == Sign.NEG) {
                    pnl = marketStatus.unrealizedPnl.add(loss);
                } else {
                    if (marketStatus.unrealizedPnl < loss) {
                        isPositive = Sign.NEG;
                        pnl = loss.sub(marketStatus.unrealizedPnl);
                    } else {
                        pnl = marketStatus.unrealizedPnl.sub(loss);
                    }
                }
            }
        } else {
            uint256 longPositionsLoss = marketStatus
                .totalLongPositionFactor
                .mul(marketStatus.lastPrice.sub(currentPrice));
            uint256 shortPositionsProfit = marketStatus
                .totalShortPositionFactor
                .mul(marketStatus.lastPrice.sub(currentPrice));

            if (shortPositionsProfit > longPositionsLoss) {
                uint256 profit = shortPositionsProfit.sub(longPositionsLoss);
                if (marketStatus.pnlSign == Sign.POS) {
                    pnl = marketStatus.unrealizedPnl.add(profit);
                } else {
                    if (marketStatus.unrealizedPnl < profit) {
                        isPositive = Sign.POS;
                        pnl = profit.sub(marketStatus.unrealizedPnl);
                    } else {
                        pnl = marketStatus.unrealizedPnl.sub(profit);
                    }
                }
            } else {
                uint256 loss = longPositionsLoss.sub(shortPositionsProfit);
                if (marketStatus.pnlSign == Sign.NEG) {
                    pnl = marketStatus.unrealizedPnl.add(loss);
                } else {
                    if (marketStatus.unrealizedPnl < loss) {
                        isPositive = Sign.NEG;
                        pnl = loss.sub(marketStatus.unrealizedPnl);
                    } else {
                        pnl = marketStatus.unrealizedPnl.sub(loss);
                    }
                }
            }
        }
    }
}
