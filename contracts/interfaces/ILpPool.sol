pragma solidity ^0.8.9;

interface ILpPool {
    function addLiquidity(uint256 liquidity) external returns(uint256);
}