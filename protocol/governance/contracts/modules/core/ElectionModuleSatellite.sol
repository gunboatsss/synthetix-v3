//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CrossChain} from "@synthetixio/core-modules/contracts/storage/CrossChain.sol";
import {IElectionModule} from "../../interfaces/IElectionModule.sol";
import {IElectionModuleSatellite} from "../../interfaces/IElectionModuleSatellite.sol";
import {ElectionCredentials} from "../../submodules/election/ElectionCredentials.sol";

contract ElectionModuleSatellite is IElectionModuleSatellite, ElectionCredentials {
    using CrossChain for CrossChain.Data;

    uint256 private constant _CROSSCHAIN_GAS_LIMIT = 100000;

    // TODO: add satellite Council initialization logic

    function cast(
        address[] calldata candidates,
        uint256[] calldata amounts
    ) public virtual override {
        CrossChain.Data storage cc = CrossChain.load();

        cc.transmit(
            cc.getChainIdAt(0),
            abi.encodeWithSelector(
                IElectionModule._recvCast.selector,
                msg.sender,
                block.chainid,
                candidates,
                amounts
            ),
            _CROSSCHAIN_GAS_LIMIT
        );
    }

    function _recvDismissMembers(address[] calldata membersToDismiss, uint256 epochIndex) external {
        CrossChain.onlyCrossChain();

        _removeCouncilMembers(membersToDismiss, epochIndex);

        emit CouncilMembersDismissed(membersToDismiss, epochIndex);
    }

    function _recvResolve(
        address[] calldata winners,
        uint256 prevEpochIndex,
        uint256 newEpochIndex
    ) external {
        CrossChain.onlyCrossChain();

        _removeAllCouncilMembers(prevEpochIndex);
        _addCouncilMembers(winners, newEpochIndex);
    }
}
