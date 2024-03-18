//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import {DecimalMath} from "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import {MathUtil} from "../utils/MathUtil.sol";
import {PerpsPrice} from "./PerpsPrice.sol";
import {Price} from "@synthetixio/spot-market/contracts/storage/Price.sol";
import {ISpotMarketSystem} from "../interfaces/external/ISpotMarketSystem.sol";
import {LiquidationAssetManager} from "./LiquidationAssetManager.sol";

/**
 * @title Configuration of all multi collateral assets used for trader margin
 */
library CollateralConfiguration {
    using DecimalMath for uint256;

    /**
     * @notice Thrown when attempting to access a not registered id
     */
    error InvalidId(uint128 id);

    struct Data {
        /**
         * @dev Collateral Id (same as synth id)
         */
        uint128 id;
        /**
         * @dev Max amount of collateral that can be used for margin
         */
        uint256 maxAmount;
        /**
         * @dev Collateral value is discounted and capped at this value.  In % units.
         */
        uint256 upperLimitDiscount;
        /**
         * @dev Collateral value is discounted and at minimum, this value.  In % units.
         */
        uint256 lowerLimitDiscount;
        /**
         * @dev This value is used to scale the impactOnSkew of the collateral.
         */
        uint256 discountScalar;
        /**
         * @dev Liquidation Asset Manager data. (see LiquidationAssetManager.Data struct).
         */
        LiquidationAssetManager.Data lam;
    }

    /**
     * @dev Load the collateral configuration data using collateral/synth id
     */
    function load(uint128 collateralId) internal pure returns (Data storage collateralConfig) {
        bytes32 s = keccak256(
            abi.encode("io.synthetix.perps-market.CollateralConfiguration", collateralId)
        );
        assembly {
            collateralConfig.slot := s
        }
    }

    /**
     * @dev Load a valid collateral configuration data using collateral/synth id
     */
    function loadValid(uint128 collateralId) internal view returns (Data storage collateralConfig) {
        collateralConfig = load(collateralId);
        if (collateralConfig.id == 0) {
            revert InvalidId(collateralId);
        }
    }

    /**
     * @dev Load a valid  collateral LiquidationAssetManager configuration data using collateral/synth id
     */
    function loadValidLam(
        uint128 collateralId
    ) internal view returns (LiquidationAssetManager.Data storage collateralLAMConfig) {
        collateralLAMConfig = load(collateralId).lam;
        if (collateralLAMConfig.id == 0) {
            revert InvalidId(collateralId);
        }
    }

    function setMax(Data storage self, uint128 synthId, uint256 maxAmount) internal {
        if (self.id == 0) self.id = synthId;
        self.maxAmount = maxAmount;
    }

    function setDiscounts(
        Data storage self,
        uint256 upperLimitDiscount,
        uint256 lowerLimitDiscount,
        uint256 discountScalar
    ) internal {
        self.upperLimitDiscount = upperLimitDiscount;
        self.lowerLimitDiscount = lowerLimitDiscount;
        self.discountScalar = discountScalar;
    }

    function getConfig(
        Data storage self
    )
        internal
        view
        returns (
            uint256 maxAmount,
            uint256 upperLimitDiscount,
            uint256 lowerLimitDiscount,
            uint256 discountScalar
        )
    {
        maxAmount = self.maxAmount;
        upperLimitDiscount = self.upperLimitDiscount;
        lowerLimitDiscount = self.lowerLimitDiscount;
        discountScalar = self.discountScalar;
    }

    function isSupported(Data storage self) internal view returns (bool) {
        return self.maxAmount != 0;
    }

    function valueInUsd(
        Data storage self,
        uint256 collateralAmount,
        ISpotMarketSystem spotMarket,
        PerpsPrice.Tolerance stalenessTolerance,
        bool useDiscount
    ) internal view returns (uint256 collateralValueInUsd, uint256 discount) {
        uint256 skewScale = spotMarket.getMarketSkewScale(self.id);
        uint256 impactOnSkew = useDiscount && skewScale != 0
            ? collateralAmount.divDecimal(skewScale).mulDecimal(self.discountScalar)
            : 0;
        discount =
            DecimalMath.UNIT -
            (
                MathUtil.max(
                    MathUtil.min(impactOnSkew, self.lowerLimitDiscount),
                    self.upperLimitDiscount
                )
            );
        uint256 discountedCollateralAmount = collateralAmount.mulDecimal(discount);

        (collateralValueInUsd, ) = spotMarket.quoteSellExactIn(
            self.id,
            discountedCollateralAmount,
            Price.Tolerance(uint256(stalenessTolerance)) // solhint-disable-line numcast/safe-cast
        );
    }
}
