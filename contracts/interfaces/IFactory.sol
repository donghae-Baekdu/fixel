// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IFactory {
    enum exchangerCall {
        yes,
        no
    }

    event LpPoolCreated(address poolAddress, address owner);

    event PositionControllerCreated(
        address positionControllerAddress,
        address owner
    );

    function getPositionController() external view returns (address);

    function createPositionController(address _lpPool, address _priceOracle)
        external
        returns (address);

    function getLpPool() external view returns (address);

    function createLpPool(address underlyingToken) external returns (address);

    function setFeeTier(
        address user,
        uint80 fee,
        exchangerCall flag
    ) external;

    function getFeeTier(address user, exchangerCall flag)
        external
        view
        returns (uint80 _fee, uint80 _feeTierDenom);
}
