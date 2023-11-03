//SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

import "@synthetixio/core-contracts/contracts/utils/ERC2771Context.sol";
import {DecimalMath} from "@synthetixio/core-contracts/contracts/utils/DecimalMath.sol";
import {MathUtil} from "../utils/MathUtil.sol";
import {SafeCastU256} from "@synthetixio/core-contracts/contracts/utils/SafeCast.sol";
import {SetUtil} from "@synthetixio/core-contracts/contracts/utils/SetUtil.sol";
import {ILiquidationModule} from "../interfaces/ILiquidationModule.sol";
import {PerpsAccount} from "../storage/PerpsAccount.sol";
import {PerpsMarket} from "../storage/PerpsMarket.sol";
import {PerpsPrice} from "../storage/PerpsPrice.sol";
import {PerpsMarketFactory} from "../storage/PerpsMarketFactory.sol";
import {GlobalPerpsMarketConfiguration} from "../storage/GlobalPerpsMarketConfiguration.sol";
import {PerpsMarketConfiguration} from "../storage/PerpsMarketConfiguration.sol";
import {GlobalPerpsMarket} from "../storage/GlobalPerpsMarket.sol";
import {MarketUpdate} from "../storage/MarketUpdate.sol";
import {IMarketEvents} from "../interfaces/IMarketEvents.sol";
import {KeeperCosts} from "../storage/KeeperCosts.sol";

/**
 * @title Module for liquidating accounts.
 * @dev See ILiquidationModule.
 */
contract LiquidationModule is ILiquidationModule, IMarketEvents {
    using DecimalMath for uint256;
    using SafeCastU256 for uint256;
    using SetUtil for SetUtil.UintSet;
    using PerpsAccount for PerpsAccount.Data;
    using PerpsMarketConfiguration for PerpsMarketConfiguration.Data;
    using GlobalPerpsMarket for GlobalPerpsMarket.Data;
    using PerpsMarketFactory for PerpsMarketFactory.Data;
    using PerpsMarket for PerpsMarket.Data;
    using GlobalPerpsMarketConfiguration for GlobalPerpsMarketConfiguration.Data;
    using KeeperCosts for KeeperCosts.Data;

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidate(uint128 accountId) external override returns (uint256 liquidationReward) {
        SetUtil.UintSet storage liquidatableAccounts = GlobalPerpsMarket
            .load()
            .liquidatableAccounts;
        PerpsAccount.Data storage account = PerpsAccount.load(accountId);
        if (!liquidatableAccounts.contains(accountId)) {
            (bool isEligible, , , , , , ) = account.isEligibleForLiquidation();

            if (isEligible) {
                uint flagCost = account.flagForLiquidation();
                liquidationReward = _liquidateAccount(account, flagCost, true);
            } else {
                revert NotEligibleForLiquidation(accountId);
            }
        } else {
            liquidationReward = _liquidateAccount(account, 0, false);
        }
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidateFlagged(
        uint256 maxNumberOfAccounts
    ) external override returns (uint256 liquidationReward) {
        uint256[] memory liquidatableAccounts = GlobalPerpsMarket
            .load()
            .liquidatableAccounts
            .values();

        uint numberOfAccountsToLiquidate = MathUtil.min(
            maxNumberOfAccounts,
            liquidatableAccounts.length
        );

        for (uint i = 0; i < numberOfAccountsToLiquidate; i++) {
            uint128 accountId = liquidatableAccounts[i].to128();
            liquidationReward += _liquidateAccount(PerpsAccount.load(accountId), 0, false);
        }
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidateFlaggedAccounts(
        uint128[] calldata accountIds
    ) external override returns (uint256 liquidationReward) {
        SetUtil.UintSet storage liquidatableAccounts = GlobalPerpsMarket
            .load()
            .liquidatableAccounts;

        for (uint i = 0; i < accountIds.length; i++) {
            uint128 accountId = accountIds[i];
            if (!liquidatableAccounts.contains(accountId)) {
                continue;
            }

            liquidationReward += _liquidateAccount(PerpsAccount.load(accountId), 0, false);
        }
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function flaggedAccounts() external view override returns (uint256[] memory accountIds) {
        return GlobalPerpsMarket.load().liquidatableAccounts.values();
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function canLiquidate(uint128 accountId) external view override returns (bool isEligible) {
        (isEligible, , , , , , ) = PerpsAccount.load(accountId).isEligibleForLiquidation();
    }

    /**
     * @inheritdoc ILiquidationModule
     */
    function liquidationCapacity(
        uint128 marketId
    )
        external
        view
        override
        returns (uint capacity, uint256 maxLiquidationInWindow, uint256 latestLiquidationTimestamp)
    {
        return
            PerpsMarket.load(marketId).currentLiquidationCapacity(
                PerpsMarketConfiguration.load(marketId)
            );
    }

    struct LiquidateAccountRuntime {
        uint128 accountId;
        uint256 totalLiquidationRewards;
        uint256 totalLiquidated;
        bool accountFullyLiquidated;
        uint256 totalLiquidationCost;
    }

    /**
     * @dev liquidates an account
     */
    function _liquidateAccount(
        PerpsAccount.Data storage account,
        uint costOfFlagExecution,
        bool includeFlaggingReward
    ) internal returns (uint256 keeperLiquidationReward) {
        LiquidateAccountRuntime memory runtime;
        runtime.accountId = account.id;
        uint256[] memory openPositionMarketIds = account.openPositionMarketIds.values();

        for (uint i = 0; i < openPositionMarketIds.length; i++) {
            uint128 positionMarketId = openPositionMarketIds[i].to128();
            uint256 price = PerpsPrice.getCurrentPrice(positionMarketId);

            (
                uint256 amountLiquidated,
                int128 newPositionSize,
                int128 sizeDelta,
                MarketUpdate.Data memory marketUpdateData
            ) = account.liquidatePosition(positionMarketId, price);

            if (amountLiquidated == 0) {
                continue;
            }
            runtime.totalLiquidated += amountLiquidated;

            emit MarketUpdated(
                positionMarketId,
                price,
                marketUpdateData.skew,
                marketUpdateData.size,
                sizeDelta,
                marketUpdateData.currentFundingRate,
                marketUpdateData.currentFundingVelocity
            );

            emit PositionLiquidated(
                runtime.accountId,
                positionMarketId,
                amountLiquidated,
                newPositionSize
            );

            // using amountToLiquidate to calculate liquidation reward
            uint256 liquidationReward = includeFlaggingReward
                ? PerpsMarketConfiguration.load(positionMarketId).calculateLiquidationReward(
                    amountLiquidated.mulDecimal(price)
                )
                : 0;

            // endorsed liquidators do not get liquidation rewards
            if (
                ERC2771Context._msgSender() !=
                PerpsMarketConfiguration.load(positionMarketId).endorsedLiquidator
            ) {
                runtime.totalLiquidationRewards += liquidationReward;
            }
        }

        runtime.totalLiquidationCost =
            KeeperCosts.load().getLiquidateKeeperCosts() +
            costOfFlagExecution;
        if (runtime.totalLiquidated > 0) {
            keeperLiquidationReward = _processLiquidationRewards(
                runtime.totalLiquidationRewards + runtime.totalLiquidationCost,
                runtime.totalLiquidationCost,
                account.getTotalCollateralValue()
            );
            runtime.accountFullyLiquidated = account.openPositionMarketIds.length() == 0;
            if (runtime.accountFullyLiquidated) {
                GlobalPerpsMarket.load().liquidatableAccounts.remove(runtime.accountId);
            }
        }

        emit AccountLiquidationAttempt(
            runtime.accountId,
            keeperLiquidationReward,
            runtime.accountFullyLiquidated
        );
    }

    /**
     * @dev process the accumulated liquidation rewards
     */
    function _processLiquidationRewards(
        uint256 totalRewards,
        uint256 costOfExecutionInUsd,
        uint256 availableMarginInUsd
    ) private returns (uint256 reward) {
        if (totalRewards == 0) {
            return 0;
        }
        // pay out liquidation rewards
        reward = GlobalPerpsMarketConfiguration.load().keeperReward(
            totalRewards,
            costOfExecutionInUsd,
            availableMarginInUsd
        );
        if (reward > 0) {
            PerpsMarketFactory.load().withdrawMarketUsd(ERC2771Context._msgSender(), reward);
        }
    }
}
