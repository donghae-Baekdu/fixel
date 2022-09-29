pragma solidity ^0.8.9;

interface ILpPool {
    function buyPosition(address user, uint256 amount) external;

    function sellPosition(address user, uint256 amount) external;

    function addCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external;

    function removeCollateral(
        address user,
        uint32 collateralId,
        uint256 amount
    ) external;

    function liquidate(
        address user,
        uint32 marketId,
        uint256 qty
    ) external;

    function getCollateralValue(address user)
        external
        view
        returns (uint256 _collateralValue);

    function getLpPositionPrice() external view returns (uint256 _price);
}
