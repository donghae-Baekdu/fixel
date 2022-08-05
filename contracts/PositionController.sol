pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPriceOracle.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ILpPool.sol";

contract PositionController is ERC721Enumerable {
    address ZD_TOKEN_ADDRESS = address(0);
    address USDC_TOKEN_ADDRESS = address(0);
    IERC20 USDC = IERC20(USDC_TOKEN_ADDRESS);

    mapping(uint256 => address) private _tokenApprovals;
    mapping(uint256 => Position) positions;

    IFactory factoryContract;
    IPriceOracle priceOracle;
    //mocking
    ILpPool poolContract;

    //mocking

    enum Side {
        LONG,
        SHORT
    }

    struct Position {
        uint80 poolId;
        uint256 margin;
        uint256 price;
        uint256 positionAmount;
        Side side;
    }

    constructor(
        address _poolContract,
<<<<<<< HEAD
        address _factoryContract,
=======
        address _marketContract,
>>>>>>> 373ee13 (Brief design)
        address _priceOracle
    ) ERC721("Renaissance Position", "rPos") {
        poolContract = ILpPool(_poolContract);
        factoryContract = IFactory(_factoryContract);
        priceOracle = IPriceOracle(_priceOracle);
    }

    function openPosition(
        uint80 poolId,
        uint256 liquidity,
        uint256 positionAmount,
        Side side
    ) external {
        require(
            USDC.balanceOf(msg.sender) >= liquidity,
            "Insufficient Balance"
        );

        USDC.transferFrom(msg.sender, address(this), liquidity);
        USDC.approve(address(poolContract), liquidity);

        uint256 margin = poolContract.addLiquidity(liquidity);
        uint32 maxLeverage = factoryContract.getMarketMaxLeverage(poolId);
        uint256 price = priceOracle.getPrice(poolId);
        require(
            maxLeverage * liquidity < positionAmount * price,
            "Excessive Leverage"
        );

        uint256 tokenId = totalSupply();
        _mint(msg.sender, tokenId);
        positions[tokenId] = Position(
            poolId,
            margin,
            price,
            positionAmount,
            side
        );
    }

    // function approve(address to, uint256 tokenId) public virtual override {
    //     address owner = ERC721.ownerOf(tokenId);
    //     require(to != owner, "ERC721: approval to current owner");

    //     require(
    //         _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
    //         "ERC721: approve caller is not token owner or approved for all"
    //     );

    //     _approve(to, tokenId);
    // }

    // function _approve(address to, uint256 tokenId) internal virtual {
    //     _tokenApprovals[tokenId] = to;
    //     emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    // }
}
