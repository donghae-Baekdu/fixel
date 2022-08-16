// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IFactory {
    event SetLpPool(address poolAddress);

    event SetPositionManager(
        address positionManagerAddress
    );

    event SetFeePot(address feePotAddress);

    event SetPriceOracle(address priceOracleAddress);

    function setPositionManager(address _positionManager) external;

    function getPositionManager() external view returns (address);

    function getLpPool() external view returns (address);

    function setLpPool(address _lpPoolAddress) external;

    function getPriceOracle() external view returns (address);

    function setPriceOracle(address _priceOracleAddress) external;

    function getFeePot() external view returns (address);

    function setFeePot(address payable _feePotAddress) external;
}