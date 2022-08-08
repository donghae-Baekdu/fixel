// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/ILpPool.sol";
import "./interfaces/IFeePot.sol";
import "./interfaces/IPositionController.sol";
import "./interfaces/IPriceOracle.sol";
import "./LpPool.sol";
import "./FeePot.sol";
import "./PositionController.sol";
import "./PriceOracle.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFactory.sol";

// change name into factory
contract Factory is Ownable, IFactory {
    uint80 public constant feeTierDenom = 10000;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp

    ILpPool public lpPool;
    IPositionController public positionController;
    IPriceOracle public priceOracle;
    IFeePot public feePot;

    function getPositionController() external view returns (address) {
        return address(positionController);
    }

    function createPositionController() external onlyOwner returns (address) {
        address positionControllerAddress = address(
            new PositionController(address(this),lpPool.underlyingToken(), address(lpPool))
        );
        positionController = IPositionController(
            payable(positionControllerAddress)
        );
        emit PositionControllerCreated(positionControllerAddress, msg.sender);
        return positionControllerAddress;
    }

    function addMarket(string memory name,uint32 _maxLeverage,uint256 threshold) public onlyOwner {
        positionController.addMarket(name, _maxLeverage, threshold);
    }

    function getLpPool() external view returns (address) {
        return address(lpPool);
    }

    function createLpPool(address underlyingToken)
        external
        onlyOwner
        returns (address)
    {
        address lpPoolAddress = address(
            new LpPool(msg.sender, underlyingToken)
        );
        lpPool = ILpPool(payable(lpPoolAddress));
        emit LpPoolCreated(lpPoolAddress, msg.sender);
        return lpPoolAddress;
    }

    function setPriceOracle(address _priceOracle) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracle);
    }

    function getPriceOracle() external view returns (address) {
        return address(priceOracle);
    }

    function getFeePot() external view returns (address) {
        return address(feePot);
    }

    function createFeePot() external onlyOwner returns (address) {
        address feePotAddress = address(new FeePot(msg.sender));
        feePot = IFeePot(payable(feePotAddress));
        emit FeePotCreated(feePotAddress, msg.sender);
        return feePotAddress;
    }
}
