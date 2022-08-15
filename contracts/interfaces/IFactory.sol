// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IFactory {
    event SetLpPool(address poolAddress);

    event SetPositionController(
        address positionControllerAddress
    );

    event SetFeePot(address feePotAddress);

    event SetPriceOracle(address priceOracleAddress);

    function setPositionController(address _positionController) external;

    function getPositionController() external view returns (address);

    function getLpPool() external view returns (address);

    function setLpPool(address _lpPoolAddress) external returns ();

    function getPriceOracle() external view returns (address);

    function setPriceOracle(address _priceOracleAddress) external;

    function getFeePot() external view returns (address);

    function setFeePot(address payable _feePotAddress) external returns ();
}