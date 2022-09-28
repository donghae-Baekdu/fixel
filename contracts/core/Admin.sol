// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IAdmin} from "../interfaces/IAdmin.sol";
import {ILpPool} from "../interfaces/ILpPool.sol";
import {IPositionManager} from "../interfaces/IPositionManager.sol";
import {IPriceOracle} from "../interfaces/IPriceOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// change name into factory
contract Admin is Ownable, IAdmin {
    uint80 public constant feeTierDenom = 10000;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp

    ILpPool public lpPool;
    IPositionManager public positionManager;
    IPriceOracle public priceOracle;

    function setPositionManager(address _positionManager) external onlyOwner {
        positionManager = IPositionManager(_positionManager);
        emit SetPositionManager(_positionManager);
    }

    function getPositionManager() external view returns (address) {
        return address(positionManager);
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
}
