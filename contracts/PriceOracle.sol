// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

<<<<<<< Updated upstream
contract PriceOracle is Ownable{
    mapping(uint80 => uint256) public prices;
    mapping(uint80 => string) public markets;
    uint80 marketCount;
=======
contract PriceOracle is Ownable {
    mapping(address => uint256) public prices;
>>>>>>> Stashed changes

    event SetPrice(uint80 poolId, uint256 prices);
    event AddMarket(uint80 poolId, string name);

    constructor() {
        marketCount=0;
    }

    function addMarket(string memory name) public onlyOwner{
     markets[marketCount] = name ;
     emit AddMarket(marketCount, name);
     marketCount = marketCount + 1;
    }

     function getPrice(uint80 poolId) external view returns(uint256) {
        require(poolId < marketCount, "Invalid Pool Id");
        return prices[poolId];
    }

    function getPrices() external view returns(uint256[] memory) {
        uint256[] memory _prices = new uint256[](marketCount);
        for(uint80 i = 0; i < marketCount; i++){
            _prices[i] = prices[i];
        }
        return _prices;
    }

<<<<<<< Updated upstream
    function setPriceOracle(uint80 poolId, uint256 price) external onlyOwner {
        prices[poolId] = price;
        emit SetPrice(poolId, price);
=======
    function setPriceOracle(address address_, uint256 price)
        external
        onlyOwner
    {
        prices[address_] = price;
        emit SetPrice(address_, price);
>>>>>>> Stashed changes
    }
}
