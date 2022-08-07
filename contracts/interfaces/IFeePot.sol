// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IFeePot {
    function withdrawFee(
        address to,
        address asset,
        uint256 value
    ) external;

    receive() external payable;
}
