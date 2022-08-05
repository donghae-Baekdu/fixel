pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract PositionController is ERC721 {
    address ZD_TOKEN_ADDRESS = address(0);
    address USDC_TOKEN_ADDRESS = address(0);

    enum Side {
        LONG, SHORT
    }

    struct Position{
        uint80 poolId;
        uint256 margin;
        uint256 amount;
        Side side;
    }
    
    constructor() ERC721("Renaissance Position", "rPos") {
    }
}