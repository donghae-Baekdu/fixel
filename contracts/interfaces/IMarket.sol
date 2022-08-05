// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IMarket {
    function getMarketMaxLeverage(uint80 poolId) external view returns (uint32);
}
