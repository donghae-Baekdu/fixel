pragma solidity ^0.8.9;

interface ITradePositionManager {
    function openPosition(
        address user,
        uint32 marketId,
        uint256 qty,
        bool isLong
    ) external;

    function closePosition(
        address user,
        uint32 marketId,
        uint256 amount
    ) external;

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

    function getPnl() external view returns (uint256 _pnlValue, bool _pnlIsPos);

    function getBalance(address user, uint32 collateralId)
        external
        view
        returns (uint256 _value, bool _isPos);
}
