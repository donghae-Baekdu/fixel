// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract PriceOracle is Ownable {
    mapping(uint80 => uint256) public prices;
    mapping(uint80 => bool) public activated;

    uint80 marketCount;
    uint256 public PRICE_DECIMAL = uint(9);
    event SetPrice(uint80 oracleId, uint256 prices);
    event AddFeed(uint80 oracleId, string name);

    modifier activatedOracle(uint80 oracleId) {
        require(activated[oracleId], "Not activated feed");
        _;
    }

    function addFeed(string memory name) public onlyOwner {
        emit AddFeed(marketCount, name);
        marketCount = marketCount + 1;
    }

    function activateFeed(uint80 oracleId) public onlyOwner {
        activated[oracleId] = true;
    }

    function getPrice(uint80 oracleId)
        external
        view
        activatedOracle(oracleId)
        returns (uint256)
    {
        require(oracleId < marketCount, "Invalid Pool Id");
        return prices[oracleId];
    }

    function getPrices() external view returns (uint256[] memory) {
        uint256[] memory _prices = new uint256[](marketCount);
        for (uint80 i = 0; i < marketCount; i++) {
            _prices[i] = prices[i];
        }
        return _prices;
    }

    function setPriceOracle(uint80 oracleId, uint256 price) external onlyOwner {
        prices[oracleId] = price;
        emit SetPrice(oracleId, price);
    }
}
