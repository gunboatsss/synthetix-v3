//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Module for managing accounts.
 * @notice Manages the system's account token NFT. Every user will need to register an account before being able to interact with the system.
 */
interface IAccountModule {
    /**
     * @notice Emitted when an account token with id `accountId` is minted to `sender`.
     */
    event AccountCreated(address indexed sender, uint128 indexed accountId);

    /**
     * @notice Emitted when `user` is granted `permission` by `sender` for account `accountId`.
     */
    event PermissionGranted(
        uint128 indexed accountId,
        bytes32 indexed permission,
        address indexed user,
        address sender
    );

    /**
     * @notice Emitted when `user` has `permission` renounced or revoked by `sender` for account `accountId`.
     */
    event PermissionRevoked(
        uint128 indexed accountId,
        bytes32 indexed permission,
        address indexed user,
        address sender
    );

    /**
     * @dev Data structure for tracking each user's permissions.
     */
    struct AccountPermissions {
        address user;
        bytes32[] permissions;
    }

    /**
     * @notice Returns an array of `AccountPermission` for the provided `accountId`.
     */
    function getAccountPermissions(
        uint128 accountId
    ) external view returns (AccountPermissions[] memory);

    /**
     * @notice Mints an account token with id `requestedAccountId` to `msg.sender`.
     *
     * Requirements:
     *
     * - `requestedAccountId` must not already be minted.
     *
     * Emits a {AccountCreated} event.
     */
    function createAccount(uint128 requestedAccountId) external;

    /**
     * @notice Called by AccountTokenModule to notify the system when the account token is transferred.
     * @dev Resets user permissions and assigns ownership of the account token to the new holder.
     *
     * Requirements:
     *
     * - `msg.sender` must be the account token.
     */
    function notifyAccountTransfer(address to, uint128 accountId) external;

    /**
     * @notice Grants `permission` to `user` for account `accountId`.
     *
     * Requirements:
     *
     * - `msg.sender` must own the account token with ID `accountId` or have the "admin" permission.
     *
     * Emits a {PermissionGranted} event.
     */
    function grantPermission(uint128 accountId, bytes32 permission, address user) external;

    /**
     * @notice Revokes `permission` from `user` for account `accountId`.
     *
     * Requirements:
     *
     * - `msg.sender` must own the account token with ID `accountId` or have the "admin" permission.
     *
     * Emits a {PermissionRevoked} event.
     */
    function revokePermission(uint128 accountId, bytes32 permission, address user) external;

    /**
     * @notice Revokes `permission` from `msg.sender` for account `accountId`.
     *
     * Emits a {PermissionRevoked} event.
     */
    function renouncePermission(uint128 accountId, bytes32 permission) external;

    /**
     * @notice Returns `true` if `user` has been granted `permission` for account `accountId`.
     */
    function hasPermission(
        uint128 accountId,
        bytes32 permission,
        address user
    ) external view returns (bool);

    /**
     * @notice Returns `true` if `target` is authorized to `permission` for account `accountId`.
     */
    function isAuthorized(
        uint128 accountId,
        bytes32 permission,
        address target
    ) external view returns (bool);

    /**
     * @notice Returns the address for the account token used by the module.
     */
    function getAccountTokenAddress() external view returns (address);

    /**
     * @notice Returns the address that owns a given account, as recorded by the system.
     */
    function getAccountOwner(uint128 accountId) external view returns (address);
}
