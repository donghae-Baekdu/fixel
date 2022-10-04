// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPriceOracle {
    function getPriceFeed(uint80 oracleId) external view returns (uint256);

    function getPriceFeeds(uint80[] memory oracleIds)
        external
        view
        returns (uint256[] memory);
}
