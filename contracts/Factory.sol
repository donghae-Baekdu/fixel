// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./interfaces/ILpPool.sol";
import "./interfaces/IFeePot.sol";
import "./interfaces/IPositionController.sol";
import "./interfaces/IPriceOracle.sol";
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

    function setPositionController(address _positionController) external onlyOwner {
        positionController = IPositionController(_positionController);
        emit SetPositionController(_positionController);
    }

    function getPositionController() external view returns (address) {
        return address(positionController);
    }

    function getLpPool() external view returns (address) {
        return address(lpPool);
    }

    function setLpPool(address _lpPoolAddress) external onlyOwner {
        lpPool = ILpPool(_lpPoolAddress);
        emit SetLpPool(_lpPoolAddress);
    }

    function setPriceOracle(address _priceOracleAddress) external onlyOwner {
        priceOracle = IPriceOracle(_priceOracleAddress);
        emit SetPriceOracle(_priceOracleAddress);
    }

    function getPriceOracle() external view returns (address) {
        return address(priceOracle);
    }

    function getFeePot() external view returns (address) {
        return address(feePot);
    }

    function setFeePot(address payable _feePotAddress) external onlyOwner {
        feePot = IFeePot(_feePotAddress);
        emit SetFeePot(_feePotAddress);
    }
}