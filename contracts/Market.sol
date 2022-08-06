// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// change name into factory
contract Market is Ownable {
    mapping(uint80 => string) public markets;
    mapping(uint80 => uint32) public maxLeverage;
    uint80 marketCount;
    mapping(address => uint80) public feeTier; // bp
    uint256 public constant feeTierDenom = 10000;

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

    function setFeeTier(address user, uint80 fee) public onlyOwner {
        feeTier[user] = fee;
    }

    function getFeeTier(address user) public view returns (uint80 _fee) {
        _fee = feeTier[user];
    }

    function getFeeDenom(address user) public view returns (uint80 _feeTierDenom) {
        _feeDenom = feeTierDenom
    }
}
