// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IAdmin} from "../interfaces/IAdmin.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// change name into factory
contract Admin is Ownable, IAdmin {
    uint80 public constant feeTierDenom = 10000;
    uint80 defaultExchangeFeeTier; // bp
    uint80 defaultLpFeeTier; // bp

    address public lpPositionManager;
    address public tradePositionManager;
    address public priceOracle;
    address public vault;

    function setTradePositionManager(address tradePositionManager_)
        external
        onlyOwner
    {
        tradePositionManager = tradePositionManager_;
        emit SetPositionManager(tradePositionManager_);
    }

    function getTradePositionManager() external view returns (address) {
        return address(tradePositionManager);
    }

    function setLpPositionManager(address lpPositionManager_)
        external
        onlyOwner
    {
        lpPositionManager = lpPositionManager_;
        emit SetLpPool(lpPositionManager_);
    }

    function getLpPositionManager() external view returns (address) {
        return lpPositionManager;
    }

    function setPriceOracle(address priceOracleAddress_) external onlyOwner {
        priceOracle = priceOracleAddress_;
        emit SetPriceOracle(priceOracleAddress_);
    }

    function getPriceOracle() external view returns (address) {
        return priceOracle;
    }

    function setVault(address vault_) external onlyOwner {
        vault = vault_;
        emit SetVault(vault_);
    }

    function getVault() external view returns (address) {
        return vault;
    }
}
