// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Import this file to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PriceOracle is Ownable{
    mapping(address => uint256) public prices;

    event SetPrice(address address_, uint256 prices);

    constructor() {}

    function setPriceOracle(address address_, uint256 price) external onlyOwner {
        prices[address_] = price;
        emit SetPrice(address_, price);
    }
}
