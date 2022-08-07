// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IFactory {
    event LpPoolCreated(address poolAddress, address owner);

    event PositionControllerCreated(
        address positionControllerAddress,
        address owner
    );

    event FeePotCreated(address poolAddress, address owner);

    function getPositionController() external view returns (address);

    function createPositionController(address _lpPool, address _priceOracle)
        external
        returns (address);

    function getLpPool() external view returns (address);

    function createLpPool(address underlyingToken) external returns (address);

<<<<<<< HEAD
    function getPriceOracle() external view returns (address);
=======
    function getFeePot() external view returns (address);

    function createFeePot() external returns (address);
>>>>>>> 974bc96 (Stop for rebase:)
}
