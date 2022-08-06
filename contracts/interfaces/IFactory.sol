// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IFactory {
    function addMarket(string memory name, uint32 _maxLeverage) external;

    function changeMaxLeverage(uint80 poolId, uint32 _maxLeverage) external;

    function getMarketMaxLeverage(uint80 poolId) external view returns (uint32);

    function getPositionController() external view returns (address);

    function createPositionController(address _lpPool, address _priceOracle)
        external
        returns (address);

    function getLpPool() external view returns (address);

    function createLpPool() external returns (address);

    function getFeeTier(address user)
        external
        view
        returns (uint80 _fee, uint80 _feeTierDenom);

    function setFeeTier(address user, uint80 fee) external;
}
