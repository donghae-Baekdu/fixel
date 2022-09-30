// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IUSD {
    function decimals() external view returns (uint8);

    function mint(address account, uint amount) external;

    function burn(uint amount) external;

    function burnFrom(address account, uint amount) external;
}
