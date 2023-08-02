//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

interface ILiquidationModule {
    // --- Events --- //

    // @dev Emitted when position has been liquidated.
    event PositionLiquidated(uint128 indexed accountId, uint128 marketId, address indexed keeper, uint256 reward);

    // --- Mutative --- //

    /**
     * @dev Flags position belonging to `accountId` for liquidation. A flagged position is frozen from all operations.
     */
    function flagPosition(uint128 accountId, uint128 marketId) external;

    /**
     * @dev Liquidates a flagged position.
     */
    function liquidatePosition(uint128 accountId, uint128 marketId) external;

    // --- Views --- //

    /**
     * @dev Returns whether a position owned by `accountId` can be flagged for liquidated.
     */
    function isPositionLiquidatable(uint128 accountId, uint128 marketId) external view returns (bool);

    /**
     * @dev Returns the IM (initial maintenance) and MM (maintenance margin) for a given account and market.
     */
    function getLiquidationMarginUsd(
        uint128 accountId,
        uint128 marketId
    ) external view returns (uint256 im, uint256 mm);

    /**
     * @dev Returns the health rating for a given account by market. A health factor of 1 means it's up for liquidation.
     */
    function getHealthRating(uint128 accountId, uint128 marketId) external view returns (uint256 healthRating);
}
