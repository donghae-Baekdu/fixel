// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract PriceOracle is Ownable {
    struct Feed {
        uint256 price;
        bool activated;
    }

    mapping(uint80 => Feed) public feeds;

    uint256 public PRICE_DECIMAL = uint(9);
    event SetPrice(uint80 oracleId, uint256 prices);
    event AddFeed(uint80 oracleId, string name);

    modifier activatedOracle(uint80 oracleId) {
        require(feeds[oracleId].activated, "Not activated feed");
        _;
    }

    function activateFeed(uint80 oracleId) public onlyOwner {
        feeds[oracleId].activated = true;
    }

    function setPriceFeed(uint80 oracleId, uint256 price) external onlyOwner {
        feeds[oracleId].price = price;
        emit SetPrice(oracleId, price);
    }

    function getPriceFeed(uint80 oracleId)
        external
        view
        activatedOracle(oracleId)
        returns (uint256)
    {
        return feeds[oracleId].price;
    }

    function getPriceFeeds(uint80[] memory oracleIds)
        external
        view
        returns (uint256[] memory)
    {
        uint256 length = oracleIds.length;
        uint256[] memory prices = new uint256[](length);
        for (uint80 i = 0; i < length; i++) {
            prices[i] = feeds[oracleIds[i]].price;
        }
        return prices;
    }
}
