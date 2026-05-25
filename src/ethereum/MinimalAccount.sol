// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import {IAccount} from
    "lib/account-abstraction/contracts/interfaces/IAccount.sol";

import {PackedUserOperation} from
    "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";

import {IEntryPoint} from
    "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from
    "lib/account-abstraction/contracts/core/Helpers.sol";

import {Ownable} from
    "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {MessageHashUtils} from
    "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {ECDSA} from
    "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/*//////////////////////////////////////////////////////////////
                        MINIMAL ACCOUNT
//////////////////////////////////////////////////////////////*/

/**
 * @title MinimalAccount
 * @author Srinidhi Kulkarni
 * @notice Minimal ERC-4337 Account Abstraction wallet
 * @dev
 * Features:
 * - ERC4337 compatible smart wallet
 * - Signature validation
 * - EntryPoint restricted execution
 * - Prefund payment support
 * - Arbitrary transaction execution
 */
contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromOwner();
    error MinimalAccount__ExecutionFailed();
    error MinimalAccount__PrefundPaymentFailed();

    /*//////////////////////////////////////////////////////////////
                        STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice ERC4337 EntryPoint contract
    IEntryPoint private immutable i_entryPoint;

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows only EntryPoint to call
     */
    modifier requireFromEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint();
        }
        _;
    }

   modifier requireFromEntryPointOrOwner() {
    if (
        msg.sender != address(i_entryPoint)
            && msg.sender != owner()
    ) {
        revert MinimalAccount__NotFromOwner();
    }
    _;
}

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param entryPoint Address of ERC4337 EntryPoint
     */
    constructor(address entryPoint) Ownable(msg.sender) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    /*//////////////////////////////////////////////////////////////
                            RECEIVE
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows contract to receive ETH
     */
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Execute arbitrary transaction
     * @param target Contract/address to call
     * @param value ETH amount to send
     * @param data Encoded function call data
     * @dev Only owner can execute
     */
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    )
        external
        requireFromEntryPointOrOwner
    {
        (bool success, bytes memory result) =
            target.call{value: value}(data);

        // silence compiler warning
        result;

        if (!success) {
            revert MinimalAccount__ExecutionFailed();
        }
    }

    /**
     * @notice Validate ERC4337 UserOperation
     * @param userOp Packed user operation
     * @param userOpHash Hash of operation
     * @param missingAccountFunds Missing ETH required by EntryPoint
     * @return validationData Validation result
     *
     * @dev Called ONLY by EntryPoint
     */
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    )
        external
        requireFromEntryPoint
        returns (uint256 validationData)
    {
        validationData =
            _validateSignature(userOp, userOpHash);

        _payPrefund(missingAccountFunds);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Validates UserOperation signature
     * @param userOp User operation
     * @param userOpHash Hash of user operation
     * @return validationData ERC4337 validation result
     */
    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        internal
        view
        returns (uint256 validationData)
    {
        /// convert to Ethereum signed message hash
        bytes32 messageHash =
            MessageHashUtils.toEthSignedMessageHash(
                userOpHash
            );

        /// recover signer from signature
        address signer =
            ECDSA.recover(
                messageHash,
                userOp.signature
            );

        /// verify signer is wallet owner
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }

        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @notice Pays missing prefund to EntryPoint
     * @param missingAccountFunds ETH required by EntryPoint
     */
    function _payPrefund(
        uint256 missingAccountFunds
    )
        internal
    {
        if (missingAccountFunds > 0) {
            (bool success,) =
                payable(msg.sender).call{
                    value: missingAccountFunds
                }("");

            if (!success) {
                revert MinimalAccount__PrefundPaymentFailed();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns EntryPoint contract
     */
    function getEntryPoint()
        external
        view
        returns (IEntryPoint)
    {
        return i_entryPoint;
    }
}