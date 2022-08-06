// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./LpPool.sol";
import "./PositionController.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFactory.sol";

// change name into factory
contract Factory is Ownable, IFactory {
    mapping(uint80 => string) public markets;
    mapping(uint80 => uint32) public maxLeverage;
    uint80 marketCount;
    mapping(address => uint80) public feeTier; // bp
    uint80 public constant feeTierDenom = 10000;

    LpPool public lpPool;
    PositionController public positionController;

    event AddMarket(uint80 poolId, string name, uint32 maxLeverage);
    event ChangeMaxLeverage(uint80 poolId, uint32 maxLeverage);
    event LpPoolCreated(address poolAddress, address owner);
    event PositionControllerCreated(
        address positionControllerAddress,
        address owner
    );

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

    function getPositionController() external view returns (address) {}

    function createPositionController(address _lpPool, address _priceOracle)
        external
        onlyOwner
        returns (address)
    {
        positionController = new PositionController(
            _lpPool,
            address(this),
            _priceOracle
        );
        emit PositionControllerCreated(address(positionController), msg.sender);
        return address(positionController);
    }

    function getLpPool() external view returns (address) {
        return address(lpPool);
    }

    function createLpPool() external onlyOwner returns (address) {
        lpPool = new LpPool(msg.sender);
        emit LpPoolCreated(address(lpPool), msg.sender);
        return address(lpPool);
    }

    function setFeeTier(address user, uint80 fee) external onlyOwner {
        feeTier[user] = fee;
    }

    function getFeeTier(address user)
        public
        view
        returns (uint80 _fee, uint80 _feeTierDenom)
    {
        _fee = feeTier[user];
        _feeTierDenom = feeTierDenom;
    }
}
