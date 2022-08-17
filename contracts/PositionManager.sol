pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";
import "./interfaces/IPositionManager.sol";
import "hardhat/console.sol";

//TODO: calculate funding fee -> complete
//TODO: apply funding fee when close position -> complete
//TODO: apply funding fee to liquidation condition -> complete

//TODO: change margin structure -> complete
//TODO: add modify position
//TODO: add sign to currentMargin, consider negative balance
contract PositionManager is ERC721Enumerable, Ownable, IPositionManager {
    using SafeMath for uint256;
    using SafeMath for uint32;

    uint256 public LEVERAGE_DECIMAL = 2;
    uint256 public FUNDING_RATE_DECIMAL = 4;
    address GD_TOKEN_ADDRESS;
    address USDC_TOKEN_ADDRESS;

    IERC20 USDC;
    IERC20 GD;

    uint32 marketCount;

    struct ValueWithSign {
        Sign sign;
        uint256 value;
    }
    mapping(uint256 => Position) public positions;

    mapping(address => mapping(uint32 => uint256[])) public userMarketPositions;
    //user -> tokenId -> index
    mapping(address => mapping(uint256 => uint256))
        public userMarketPositionsIndex;

    mapping(uint32 => MarketStatus) public marketStatus;
    mapping(uint32 => MarketInfo) public marketInfo;
    mapping(uint32 => FundingFee) public accFundingFee;

    IFactory factoryContract;

    constructor(
        address _factoryContract,
        address _usdc,
        address _gd
    ) ERC721("Renaissance Position", "rPos") {
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
        require(
            leverage <= marketInfo[marketId].maxLeverage,
            "Excessive Leverage"
        );

        ILpPool poolContract = ILpPool(factoryContract.getLpPool());
        IPriceOracle priceOracle = IPriceOracle(
            factoryContract.getPriceOracle()
        );

        uint256 margin = poolContract.addLiquidity(
            msg.sender,
            liquidity,
            liquidity.mul(leverage),
            ILpPool.exchangerCall.yes
        );

        uint256 price = priceOracle.getPrice(marketId);

        uint256 tokenId = totalSupply();
        _mint(msg.sender, tokenId);

        positions[tokenId] = Position(
            marketId,
            margin,
            margin.mul(leverage),
            price,
            margin.mul(leverage).div(price).div(uint(10)**LEVERAGE_DECIMAL),
            uint256(0),
            accFundingFee[marketId].accRate,
            uint256(block.timestamp),
            uint256(0),
            accFundingFee[marketId].sign,
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

    function closePosition(uint32 marketId, uint256 tokenId)
        external
        returns (uint256)
    {
        require(ownerOf(tokenId) == msg.sender, "Invalid Token Id");
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
        uint256 receiveAmount = _closePosition(marketId, tokenId);
        console.log(receiveAmount);
        return receiveAmount;
    }

    function liquidate(uint32 marketId, uint256 tokenId) external {
        require(positions[tokenId].status == Status.OPEN, "Already Closed");

        uint256 currentMargin = calculateMarginWithFundingFee(tokenId);

        uint256 marginRatio = currentMargin.mul(uint256(10000)).div(
            positions[tokenId].notionalValue
        );
        require(
            marginRatio < marketInfo[marketId].liquidationThreshold,
            "Not Liquidatable"
        );
        uint256 returnAmount = _closePosition(marketId, tokenId);
        USDC.transfer(msg.sender, returnAmount);
        emit Liquidation(ownerOf(tokenId), msg.sender, marketId, tokenId);
    }

    function addMargin(
        uint256 tokenId,
        uint256 liquidity,
        uint256 notionalValue
    ) external {
        uint256 currentMargin = calculateMarginWithFundingFee(tokenId);
        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(positions[tokenId].marketId);

        (uint256 margin, uint256 fee, uint256 notionalValueAsGd) = ILpPool(
            factoryContract.getLpPool()
        ).addLiquidity(
                msg.sender,
                liquidity,
                notionalValue,
                ILpPool.exchangerCall.yes
            );

        applyFundingFeeToPosition(tokenId);

        positions[tokenId].margin = positions[tokenId].margin.add(
            margin.sub(fee)
        );
        positions[tokenId].price = (
            positions[tokenId].price.mul(positions[tokenId].notionalValue).add(
                currentPrice.mul(notionalValueAsGd)
            )
        ).div(positions[tokenId].notionalValue.add(notionalValueAsGd));
        positions[tokenId].notionalValue = positions[tokenId].notionalValue.add(
            noitonalValueAsGd
        );

        updateMarketStatusAfterTrade(
            positions[tokenId].marketId,
            positions[tokenId].side,
            TradeType.OPEN,
            positions[tokenId].margin.sub(fee),
            (
                positions[tokenId].notionalValue.div(currentPrice).div(
                    uint(10)**LEVERAGE_DECIMAL
                )
            ).sub(positions[tokenId].factor)
        );

        positions[tokenId].factor = positions[tokenId]
            .notionalValue
            .div(currentPrice)
            .div(uint(10)**LEVERAGE_DECIMAL);
    }

    function removeMargin(
        uint256 tokenId,
        uint256 liquidity,
        uint256 notionalValue
    ) external {
        uint256 currentMargin = calculateMarginWithFundingFee(tokenId);
        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(positions[tokenId].marketId);

        //TODO
        (uint256 margin, uint256 fee, uint256 notionalValueAsGd) = ILpPool(
            factoryContract.getLpPool()
        ).removeLiquidity(
                msg.sender,
                liquidity,
                notionalValue,
                ILpPool.exchangerCall.yes
            );

        applyFundingFeeToPosition(tokenId);

        positions[tokenId].margin = positions[tokenId].margin.add(
            margin.sub(fee)
        );
        positions[tokenId].price = (
            positions[tokenId].price.mul(positions[tokenId].notionalValue).add(
                currentPrice.mul(notionalValueAsGd)
            )
        ).div(positions[tokenId].notionalValue.add(notionalValueAsGd));
        positions[tokenId].notionalValue = positions[tokenId].notionalValue.add(
            noitonalValueAsGd
        );

        updateMarketStatusAfterTrade(
            positions[tokenId].marketId,
            positions[tokenId].side,
            TradeType.OPEN,
            positions[tokenId].margin.sub(fee),
            (
                positions[tokenId].notionalValue.div(currentPrice).div(
                    uint(10)**LEVERAGE_DECIMAL
                )
            ).sub(positions[tokenId].factor)
        );

        positions[tokenId].factor = positions[tokenId]
            .notionalValue
            .div(currentPrice)
            .div(uint(10)**LEVERAGE_DECIMAL);
    }

    function calculateMargin(uint256 tokenId) public view returns (uint256) {
        require(positions[tokenId].status == Status.OPEN, "Alread Closed");
        uint256 currentPrice = IPriceOracle(factoryContract.getPriceOracle())
            .getPrice(positions[tokenId].marketId);

        if (positions[tokenId].side == Side.LONG) {
            if (currentPrice > positions[tokenId].price) {
                return
                    positions[tokenId].margin.add(
                        (currentPrice.sub(positions[tokenId].price)).mul(
                            positions[tokenId].factor
                        )
                    );
            } else {
                return
                    positions[tokenId].margin.sub(
                        (positions[tokenId].price.sub(currentPrice)).mul(
                            positions[tokenId].factor
                        )
                    );
            }
        } else {
            if (currentPrice > positions[tokenId].price) {
                return
                    positions[tokenId].margin.sub(
                        (currentPrice.sub(positions[tokenId].price)).mul(
                            positions[tokenId].factor
                        )
                    );
            } else {
                return
                    positions[tokenId].margin.add(
                        (positions[tokenId].price.sub(currentPrice)).mul(
                            positions[tokenId].factor
                        )
                    );
            }
        }
    }

    function calculateMarginWithFundingFee(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        (Sign fundingFeeSign, uint256 fundingFee) = calculatePositionFundingFee(
            tokenId
        );
        uint256 currentMargin = calculateMargin(tokenId);

        if (fundingFeeSign == Sign.POS) {
            currentMargin = currentMargin.add(fundingFee);
        } else {
            if (currentMargin < fundingFee) {
                currentMargin = 0;
            } else {
                currentMargin = currentMargin.sub(fundingFee);
            }
        }
        return currentMargin;
    }

    function _closePosition(uint32 marketId, uint256 tokenId)
        internal
        returns (uint256)
    {
        applyFundingFeeToPosition(tokenId);
        updateMarketStatusAfterTrade(
            marketId,
            positions[tokenId].side,
            TradeType.CLOSE,
            positions[tokenId].margin,
            positions[tokenId].factor
        );

        ValueWithSign memory pnl;

        if (positions[tokenId].side == Side.LONG) {
            if (marketStatus[marketId].lastPrice > positions[tokenId].price) {
                pnl.sign = Sign.POS;
                pnl.value = (
                    marketStatus[marketId].lastPrice.sub(
                        positions[tokenId].price
                    )
                ).mul(positions[tokenId].factor);
            } else {
                pnl.sign = Sign.NEG;
                pnl.value = (
                    positions[tokenId].price.sub(
                        marketStatus[marketId].lastPrice
                    )
                ).mul(positions[tokenId].factor);
            }
        } else {
            if (marketStatus[marketId].lastPrice > positions[tokenId].price) {
                pnl.sign = Sign.NEG;
                pnl.value = (
                    marketStatus[marketId].lastPrice.sub(
                        positions[tokenId].price
                    )
                ).mul(positions[tokenId].factor);
            } else {
                pnl.sign = Sign.POS;
                pnl.value = (
                    positions[tokenId].price.sub(
                        marketStatus[marketId].lastPrice
                    )
                ).mul(positions[tokenId].factor);
            }
        }
        /*
        (Sign deltaSign, uint256 delta) = calculatePositionFundingFee(tokenId);
        (deltaSign, delta) = calculateUnsignedAdd(
            pnl.sign,
            pnl.value,
            deltaSign,
            delta
        );
        */
        address lpPoolAddress = factoryContract.getLpPool();
        uint256 receiveAmount;

        //realize pnl
        (
            marketStatus[marketId].pnlSign,
            marketStatus[marketId].unrealizedPnl
        ) = calculateUnsignedSub(
            marketStatus[marketId].pnlSign,
            marketStatus[marketId].unrealizedPnl,
            pnl.sign,
            pnl.value
        );

        (, uint256 closeAmount) = calculateUnsignedAdd(
            Sign.POS,
            positions[tokenId].notionalValue,
            pnl.sign,
            pnl.value
        );

        if (pnl.sign == Sign.POS) {
            ILpPool(lpPoolAddress).mint(address(this), pnl.value);

            receiveAmount = ILpPool(lpPoolAddress).removeLiquidity(
                ownerOf(tokenId),
                positions[tokenId].margin.add(pnl.value),
                closeAmount,
                ILpPool.exchangerCall.yes
            );
        } else {
            uint256 burnAmount = pnl.value > positions[marketId].margin
                ? positions[marketId].margin
                : pnl.value;
            ILpPool(lpPoolAddress).burn(address(this), burnAmount);
            receiveAmount = ILpPool(lpPoolAddress).removeLiquidity(
                ownerOf(tokenId),
                positions[tokenId].margin.sub(burnAmount),
                closeAmount,
                ILpPool.exchangerCall.yes
            );
        }

        positions[tokenId].status = Status.CLOSE;
        positions[tokenId].closePrice = marketStatus[marketId].lastPrice;
        positions[tokenId].closeTimestamp = uint256(block.timestamp);

        emit ClosePosition(
            ownerOf(tokenId),
            marketId,
            positions[tokenId].side,
            pnl.sign,
            tokenId,
            positions[tokenId].margin,
            pnl.value,
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
            /*
            if (accFundingFee[i].feeSign == Sign.POS) {
                totalProfit = totalProfit.add(
                    accFundingFee[i].unrealizedFundingFee
                );
            } else {
                totalLoss = totalLoss.add(accFundingFee[i].unrealizedFundingFee);
            }*/
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
    {
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
        (Sign resSign, uint256 resNum) = calculateUnsignedSub(
            accFundingFee[positions[tokenId].marketId].sign,
            accFundingFee[positions[tokenId].marketId].accRate,
            positions[tokenId].initialFundingFeeSign,
            positions[tokenId].initialAccFundingFee
        );
        //TODO: should re-write after applying notional value
        fundingFee = positions[tokenId].notionalValue.mul(resNum).div(
            uint256(10)**FUNDING_RATE_DECIMAL
        );
        if (positions[tokenId].side == Side.LONG) {
            if (resSign == Sign.POS) {
                sign = Sign.NEG;
            } else {
                sign = Sign.POS;
            }
        } else {
            if (resSign == Sign.POS) {
                sign = Sign.POS;
            } else {
                sign = Sign.NEG;
            }
        }
    }

    function applyFundingRate(
        uint32 marketId,
        Sign sign,
        uint256 fundingRate
    ) external onlyOwner {
        (Sign resSign, uint256 resNum) = calculateUnsignedAdd(
            accFundingFee[marketId].sign,
            accFundingFee[marketId].accRate,
            sign,
            fundingRate
        );
        accFundingFee[marketId].sign = resSign;
        accFundingFee[marketId].accRate = resNum;
        accFundingFee[marketId].lastTimestamp = uint256(block.timestamp);
        emit ApplyFundingRate(marketId, sign, fundingRate);
    }

    function applyFundingFeeToPosition(uint256 tokenId)
        public
        returns (Sign sign, uint256 fee)
    {
        require(positions[tokenId].status == Status.OPEN, "Already Closed");
        (
            Sign fundingFeeSign,
            uint256 currentFundingFee
        ) = calculatePositionFundingFee(tokenId);

        (, positions[tokenId].margin) = calculateUnsignedAdd(
            Sign.POS,
            positions[tokenId].margin,
            fundingFeeSign,
            currentFundingFee
        );

        (
            accFundingFee[positions[tokenId].marketId].feeSign,
            accFundingFee[positions[tokenId].marketId].unrealizedFundingFee
        ) = calculateUnsignedSub(
            accFundingFee[positions[tokenId].marketId].feeSign,
            accFundingFee[positions[tokenId].marketId].unrealizedFundingFee,
            fundingFeeSign,
            currentFundingFee
        );

        positions[tokenId].sign = accFundingFee[positions[tokenId].marketId]
            .sign;
        positions[tokenId].initialAccFundingFee = accFundingFee[
            positions[tokenId].marketId
        ].accRate;
    }

    function calculateUnsignedAdd(
        Sign signA,
        uint256 numA,
        Sign signB,
        uint256 numB
    ) internal pure returns (Sign resSign, uint256 resNum) {
        if (signA == signB) {
            return (signA, numA.add(numB));
        } else {
            if (numA > numB) {
                return (signA, numA.sub(numB));
            } else {
                return (signB, numB.sub(numA));
            }
        }
    }

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
