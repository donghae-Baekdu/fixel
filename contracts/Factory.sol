// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./LpPool.sol";
import "./PositionController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFactory.sol";

// change name into factory
contract Factory is Ownable, IFactory {
    uint80 public constant feeTierDenom = 10000;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp

    LpPool public lpPool;
    PositionController public positionController;

    function getPositionController() external view returns (address) {
        return address(positionController);
    }

    function createPositionController(address _lpPool, address _priceOracle)
        external
        onlyOwner
        returns (address)
    {
        positionController = new PositionController(address(this));
        emit PositionControllerCreated(address(positionController), msg.sender);
        return address(positionController);
    }

    function getLpPool() external view returns (address) {
        return address(lpPool);
    }

    function createLpPool(address underlyingToken)
        external
        onlyOwner
        returns (address)
    {
        lpPool = new LpPool(msg.sender, underlyingToken);
        emit LpPoolCreated(address(lpPool), msg.sender);
        return address(lpPool);
    }
}
