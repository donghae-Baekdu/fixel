// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUSD is IERC20 {
    function underlyingAsset() external view returns(address);

    function decimals() external view returns (uint8);

    function mint(address account, uint amount) external;

    function burn(uint amount) external;

    function burnFrom(address account, uint amount) external;
}
