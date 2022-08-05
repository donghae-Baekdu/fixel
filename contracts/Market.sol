// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Market is Ownable {
    mapping(uint80 => string) public markets;
    mapping(uint80 => uint32) public maxLeverage;
    uint80 marketCount;

    event AddMarket(uint80 poolId, string name, uint32 maxLeverage);
    event ChangeMaxLeverage(uint80 poolId, uint32 maxLeverage);

    constructor() {
        marketCount = 0;
    }

    function addMarket(string memory name, uint32 _maxLeverage)
        public
        onlyOwner
    {
        markets[marketCount] = name;
        maxLeverage[marketCount] = _maxLeverage;
        emit AddMarket(marketCount, name, _maxLeverage);
        marketCount = marketCount + 1;
    }

    function changeMaxLeverage(uint80 poolId, uint32 _maxLeverage)
        public
        onlyOwner
    {
        require(_maxLeverage > 0, "Max Leverage Should Be Positive");
        maxLeverage[poolId] = _maxLeverage;
        emit ChangeMaxLeverage(poolId, _maxLeverage);
    }

    function getMarketMaxLeverage(uint80 poolId)
        external
        view
        returns (uint32)
    {
        require(poolId < marketCount, "Invalid Pool Id");
        return maxLeverage[poolId];
    }

    function getPositionManager() external view returns (address) {}

    function getLpPool() external view returns (address) {}
}
