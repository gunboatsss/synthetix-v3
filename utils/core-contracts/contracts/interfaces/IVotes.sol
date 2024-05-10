// SPDX-License-Identifier: MIT
pragma solidity >=0.8.11 <0.9.0;

interface IVotes {
    /**
     * @dev Delegates votes from the sender to `delegatee`.
     */
    function delegate(address delegatee) external;
}
