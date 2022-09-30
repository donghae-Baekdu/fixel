// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IVault {
    function withdrawalRequest(
        address token,
        address recipient,
        uint256 amount
    ) external;
}
