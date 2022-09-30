// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IAdmin {
    event SetLpPool(address poolAddress);

    event SetPositionManager(address positionManagerAddress);

    event SetPriceOracle(address priceOracleAddress);

    event SetVault(address vault);

    function setTradePositionManager(address positionManager_) external;

    function getTradePositionManager() external view returns (address);

    function setLpPositionManager(address lpPoolAddress_) external;

    function getLpPositionManager() external view returns (address);

    function setPriceOracle(address priceOracleAddress_) external;

    function getPriceOracle() external view returns (address);

    function setVault(address vault_) external;

    function getVault() external view returns (address);
}
