// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IPriceOracle {
    function getPrice(uint80 poolId) external view returns(uint256);
    function getPrices() external view returns(uint256[] memory);
}