//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../utils/ContractUtil.sol";
import "../common/CommonErrors.sol";
import "./ProxyStorage.sol";

contract UUPSImplementation is ProxyStorage, ContractUtil, CommonErrors {
    event Upgraded(address implementation);

    function _upgradeTo(address newImplementation) internal virtual {
        if (newImplementation == address(0)) {
            revert InvalidAddress(newImplementation);
        }

        if (!_isContract(newImplementation)) {
            revert InvalidContract(newImplementation);
        }

        _proxyStore().implementation = newImplementation;

        emit Upgraded(newImplementation);
    }

    function getImplementation() external view returns (address) {
        return _proxyStore().implementation;
    }
}
