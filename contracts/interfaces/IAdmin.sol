// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IAdmin {
    event SetLpPool(address poolAddress);

    event SetPositionManager(address positionManagerAddress);

    event SetPriceOracle(address priceOracleAddress);

    event SetVault(address vault);

    event SetStablecoin(address stablecoinAddress);

    event SetFeePot(address feePotAddress);

    function setTradePositionManager(address positionManager_) external;

    function getTradePositionManager() external view returns (address);

    function setLpPositionManager(address lpPoolAddress_) external;

    function getLpPositionManager() external view returns (address);

    function setPriceOracle(address priceOracleAddress_) external;

    function getPriceOracle() external view returns (address);

    function setVault(address vault_) external;

    function getVault() external view returns (address);

    function setFeePot(address feePot_) external;

    function getFeePot() external view returns (address);

    function setStablecoin(address _stablecoin) external;

    function getStablecoin() external view returns (address);
}
