// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IMarket {
    function addMarket(string memory name, uint32 _maxLeverage) external;

    function changeMaxLeverage(uint80 poolId, uint32 _maxLeverage) external;

    function getMarketMaxLeverage(uint80 poolId) external view returns (uint32);

    function getPositionManager() external view returns (address);

    function getLpPool() external view returns (address);
}
